//
//  ArticleListViewController.swift
//  iZSM
//
//  Created by Naitong Yu on 2016/11/22.
//  Copyright © 2016年 Naitong Yu. All rights reserved.
//

import UIKit
import SVProgressHUD

class ArticleListViewController: BaseTableViewController, UISearchControllerDelegate, UISearchBarDelegate {
    
    private let kArticleListCellIdentifier = "ArticleListCell"
    var boardID: String?
    var boardName: String? {
        didSet { title = boardName }
    }
    
    private var indexMap = [String : IndexPath]()
    
    var threadLoaded = 0
    private var threadRange: NSRange {
        return NSMakeRange(threadLoaded, setting.threadCountPerSection)
    }
    var threads: [[SMThread]] = [[SMThread]]() {
        didSet { tableView?.reloadData() }
    }
    
    var originalThreadLoaded: Int? = nil
    var originalThread: [[SMThread]]?
    var searchMode = false {
        didSet {
            self.fd_interactivePopDisabled = searchMode // not allow swipe to pop when in search mode
        }
    }
    
    var searchString: String? {
        return searchController?.searchBar.text
    }
    var selectedIndex: Int = 0
    
    private var searchController: UISearchController?
    
    func didDismissSearchController(_ searchController: UISearchController) {
        searchMode = false
        api.cancel()
        refreshHeaderEnabled = true
        threads = originalThread!
        threadLoaded = originalThreadLoaded!
        originalThread = nil
    }
    
    func didPresentSearchController(_ searchController: UISearchController) {
        searchMode = true
        api.cancel()
        refreshHeaderEnabled = false
        originalThread = threads
        originalThreadLoaded = threadLoaded
        threads = [[SMThread]]()
        threadLoaded = 0
    }
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        search(forText: searchString, scope: selectedIndex)
    }
    
    func searchBar(_ searchBar: UISearchBar, selectedScopeButtonIndexDidChange selectedScope: Int) {
        if selectedScope != selectedIndex {
            selectedIndex = selectedScope
            search(forText: searchBar.text, scope: selectedScope)
        }
    }
    
    func search(forText searchString: String?, scope: Int) {
        if let boardID = self.boardID, let searchString = searchString, !searchString.isEmpty {
            self.threadLoaded = 0
            let currentMode = searchMode
            networkActivityIndicatorStart(withHUD: true)
            var result: [SMThread]?
            DispatchQueue.global().async {
                if scope == 0 {
                    result = self.api.searchArticleInBoard(boardID: boardID,
                                                           title: searchString,
                                                           user: nil,
                                                           inRange: self.threadRange)
                } else if scope == 1 {
                    result = self.api.searchArticleInBoard(boardID: boardID,
                                                           title: nil,
                                                           user: searchString,
                                                           inRange: self.threadRange)
                }
                DispatchQueue.main.async {
                    networkActivityIndicatorStop(withHUD: true)
                    if currentMode != self.searchMode { return } //模式已经改变，则丢弃数据
                    self.threads.removeAll()
                    if let result = result {
                        self.threads.append(result)
                        self.threadLoaded += result.count
                    }
                    self.api.displayErrorIfNeeded()
                }
            }
        }
    }
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.register(ArticleListViewCell.self, forCellReuseIdentifier: kArticleListCellIdentifier)
        
        // search related
        definesPresentationContext = true
        searchController = UISearchController(searchResultsController: nil)
        searchController?.obscuresBackgroundDuringPresentation = false
        searchController?.delegate = self
        searchController?.searchBar.delegate = self
        searchController?.searchBar.scopeButtonTitles = ["标题关键字", "同作者"]
        searchController?.searchBar.selectedScopeButtonIndex = 0
        navigationItem.searchController = searchController
        navigationItem.scrollEdgeAppearance = UINavigationBarAppearance() // fix transparent search bar
        
        let composeButton = UIBarButtonItem(barButtonSystemItem: .compose,
                                            target: self,
                                            action: #selector(composeArticle(_:)))
        navigationItem.rightBarButtonItem =  composeButton
    }
    
    override func clearContent() {
        threads.removeAll()
    }
    
    override func fetchDataDirectly(showHUD: Bool, completion: (() -> Void)? = nil) {
        threadLoaded = 0
        if let boardID = self.boardID {
            let currentMode = self.searchMode
            networkActivityIndicatorStart(withHUD: showHUD)
            DispatchQueue.global().async {
                var threadSection = self.api.getThreadListForBoard(boardID: boardID,
                                                                   inRange: self.threadRange,
                                                                   brcmode: .NotClear)
                if self.setting.hideAlwaysOnTopThread {
                    threadSection = threadSection?.filter {
                        !$0.flags.hasPrefix("d") && !$0.flags.hasPrefix("D")
                    }
                }
                DispatchQueue.main.async {
                    networkActivityIndicatorStop(withHUD: showHUD)
                    completion?()
                    if currentMode != self.searchMode { return } //如果模式已经被切换，则数据丢弃
                    if let threadSection = threadSection {
                        self.threads.removeAll()
                        self.threadLoaded += threadSection.count
                        self.threads.append(threadSection)
                    }
                    self.api.displayErrorIfNeeded()
                }
            }
        } else {
            completion?()
        }
    }
    
    private var _isFetchingMoreData = false
    private var _semaphore = DispatchSemaphore(value: 1)
    
    override func fetchMoreData() {
        if let boardID = self.boardID {
            
            _semaphore.wait()
            if !_isFetchingMoreData {
                _isFetchingMoreData = true
                _semaphore.signal()
            } else {
                _semaphore.signal()
                return
            }
            
            let currentMode = self.searchMode
            let searchString = self.searchString
            networkActivityIndicatorStart()
            DispatchQueue.global().async {
                var threadSection: [SMThread]?
                if self.searchMode {
                    if self.selectedIndex == 0 {
                        threadSection = self.api.searchArticleInBoard(boardID: boardID,
                                                                      title: searchString,
                                                                      user: nil,
                                                                      inRange: self.threadRange)
                    } else if self.selectedIndex == 1 {
                        threadSection = self.api.searchArticleInBoard(boardID: boardID,
                                                                      title: nil,
                                                                      user: searchString,
                                                                      inRange: self.threadRange)
                    }
                } else {
                    threadSection = self.api.getThreadListForBoard(boardID: boardID,
                                                                   inRange: self.threadRange,
                                                                   brcmode: .NotClear)
                }
                // 过滤掉置顶帖
                if self.setting.hideAlwaysOnTopThread && !self.searchMode {
                    threadSection = threadSection?.filter {
                        !$0.flags.hasPrefix("d") && !$0.flags.hasPrefix("D")
                    }
                }
                // 过滤掉重复的帖子
                let loadedThreadIds = self.threads.reduce(Set<Int>()) {
                    $0.union(Set($1.map { $0.id }))
                }
                threadSection = threadSection?.filter {
                    !loadedThreadIds.contains($0.id)
                }
                DispatchQueue.main.async {
                    self._isFetchingMoreData = false
                    networkActivityIndicatorStop()
                    if self.searchMode != currentMode {
                        return //如果模式已经改变，则此数据需要丢弃
                    }
                    if let threadSection = threadSection, threadSection.count > 0 {
                        self.threadLoaded += threadSection.count
                        self.threads.append(threadSection)
                    }
                    self.api.displayErrorIfNeeded()
                }
            }
        }
    }
    
    // MARK: - Table view data source
    override func numberOfSections(in tableView: UITableView) -> Int {
        return threads.count
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return threads[section].count
    }
    
    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        if threads.isEmpty {
            return
        }
        if indexPath.section == threads.count - 1 && indexPath.row == threads[indexPath.section].count / 3 * 2 {
            fetchMoreData()
        }
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: kArticleListCellIdentifier, for: indexPath) as! ArticleListViewCell
        cell.thread = threads[indexPath.section][indexPath.row]
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let acvc = ArticleContentViewController()
        let thread = threads[indexPath.section][indexPath.row]
        acvc.articleID = thread.id
        acvc.boardID = thread.boardID
        acvc.boardName = thread.boardName
        acvc.title = thread.subject
        acvc.hidesBottomBarWhenPushed = true
        if thread.flags.hasPrefix("*") {
            var readThread = thread
            let flags = thread.flags
            readThread.flags = " " + flags[flags.index(after: flags.startIndex)...]
            threads[indexPath.section][indexPath.row] = readThread
        }
        
        show(acvc, sender: self)
    }
    
    @objc private func composeArticle(_ sender: UIBarButtonItem) {
        let cavc = ComposeArticleController()
        cavc.boardID = boardID
        cavc.completionHandler = { [unowned self] in
            self.fetchDataDirectly(showHUD: false)
        }
        let nvc = NTNavigationController(rootViewController: cavc)
        nvc.modalPresentationStyle = .formSheet
        present(nvc, animated: true)
    }
}

extension ArticleListViewController {
    override func tableView(_ tableView: UITableView, contextMenuConfigurationForRowAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        guard let cell = tableView.cellForRow(at: indexPath) else { return nil }
        let thread = threads[indexPath.section][indexPath.row]
        let identifier = NSUUID().uuidString
        indexMap[identifier] = indexPath
        let urlString: String
        switch self.setting.displayMode {
        case .nForum:
            urlString = "https://www.newsmth.net/nForum/#!article/\(thread.boardID)/\(thread.id)"
        case .www2:
            urlString = "https://www.newsmth.net/bbstcon.php?board=\(thread.boardID)&gid=\(thread.id)"
        case .mobile:
            urlString = "https://m.newsmth.net/article/\(thread.boardID)/\(thread.id)"
        }
        let preview: UIContextMenuContentPreviewProvider = { [unowned self] in
            self.getViewController(with: thread)
        }
        let actions: UIContextMenuActionProvider = { [unowned self] seggestedActions in
            let openAction = UIAction(title: "浏览网页版", image: UIImage(systemName: "safari")) { [unowned self] action in
                let webViewController = NTSafariViewController(url: URL(string: urlString)!)
                self.present(webViewController, animated: true)
            }
            let starAction = UIAction(title: "收藏本帖", image: UIImage(systemName: "star")) { [unowned self] action in
                let alertController = UIAlertController(title: "备注", message: nil, preferredStyle: .alert)
                alertController.addTextField { textField in
                    textField.placeholder = "备注信息（可选）"
                    textField.returnKeyType = .done
                }
                let okAction = UIAlertAction(title: "确定", style: .default) { [unowned alertController] _ in
                    if let textField = alertController.textFields?.first {
                        var comment: String? = nil
                        if let text = textField.text, text.count > 0 {
                            comment = text
                        }
                        networkActivityIndicatorStart(withHUD: true)
                        StarThread.updateInfo(articleID: thread.id, articleTitle: thread.subject, authorID: thread.authorID, boardID: thread.boardID, comment: comment) {
                            networkActivityIndicatorStop(withHUD: true)
                            SVProgressHUD.showSuccess(withStatus: "收藏成功")
                        }
                    }
                }
                alertController.addAction(okAction)
                alertController.addAction(UIAlertAction(title: "取消", style: .cancel, handler: nil))
                self.present(alertController, animated: true)
            }
            let shareAction = UIAction(title: "分享本帖", image: UIImage(systemName: "square.and.arrow.up")) { [unowned self] action in
                let title = "水木\(thread.boardName)版：【\(thread.subject)】"
                let url = URL(string: urlString)!
                let activityViewController = UIActivityViewController(activityItems: [title, url],
                                                                      applicationActivities: nil)
                activityViewController.popoverPresentationController?.sourceView = cell
                activityViewController.popoverPresentationController?.sourceRect = cell.bounds
                self.present(activityViewController, animated: true)
            }
            return UIMenu(title: "", children: [openAction, starAction, shareAction])
        }
        return UIContextMenuConfiguration(identifier: identifier as NSString, previewProvider: preview, actionProvider: actions)
    }
    
    override func tableView(_ tableView: UITableView, willPerformPreviewActionForMenuWith configuration: UIContextMenuConfiguration, animator: UIContextMenuInteractionCommitAnimating) {
        animator.addCompletion { [unowned self] in
            guard let identifier = configuration.identifier as? String else { return }
            guard let indexPath = self.indexMap[identifier] else { return }
            let thread = self.threads[indexPath.section][indexPath.row]
            if thread.flags.hasPrefix("*") {
                var readThread = thread
                let flags = thread.flags
                readThread.flags = " " + flags.dropFirst()
                self.threads[indexPath.section][indexPath.row] = readThread
            }
            let acvc = self.getViewController(with: thread)
            self.show(acvc, sender: self)
        }
    }
    
    private func getViewController(with thread: SMThread) -> ArticleContentViewController {
        let acvc = ArticleContentViewController()
        acvc.articleID = thread.id
        acvc.boardID = thread.boardID
        acvc.boardName = thread.boardName
        acvc.title = thread.subject
        acvc.hidesBottomBarWhenPushed = true
        return acvc
    }
}
