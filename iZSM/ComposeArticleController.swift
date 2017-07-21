//
//  ComposeArticleController.swift
//  iZSM
//
//  Created by Naitong Yu on 2016/11/23.
//  Copyright © 2016年 Naitong Yu. All rights reserved.
//

import UIKit
import MobileCoreServices
import SnapKit
import SVProgressHUD

class ComposeArticleController: UIViewController, UITextFieldDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    let titleHintLabel = UILabel()
    let titleTextField = UITextField()
    let contentTextView = UITextView()
    let countLabel = UILabel()
    var doneButton: UIBarButtonItem?
    
    var boardID: String?
    weak var delegate: ComposeArticleControllerDelegate?
    
    var replyMode: Bool = false
    var replyByMail: Bool = false
    var originalArticle: SMArticle?
    
    let signature = "\n- 来自「最水木 for iOS」"
    
    var articleTitle: String? {
        get { return titleTextField.text }
        set { titleTextField.text = newValue }
    }
    
    var articleContent: String? {
        get { return contentTextView.text }
        set { contentTextView.text = newValue }
    }
    
    var keyboardHeight: Constraint?
    
    private let api = SmthAPI()
    private let setting = AppSetting.shared
    
    private var attachedImage: UIImage? //图片附件，如果为nil，则表示不含附件
    
    func setEditable(_ editable: Bool) {
        titleTextField.isEnabled = editable
        contentTextView.isEditable = editable
    }
    
    private func setupUI() {
        let cornerRadius: CGFloat = 4
        title = "发表文章"
        titleHintLabel.text = "标题"
        titleHintLabel.font = UIFont.systemFont(ofSize: 14)
        titleHintLabel.textAlignment = .center
        titleHintLabel.layer.cornerRadius = cornerRadius
        titleHintLabel.layer.masksToBounds = true
        titleHintLabel.setContentHuggingPriority(UILayoutPriorityDefaultHigh, for: .horizontal)
        titleHintLabel.setContentCompressionResistancePriority(UILayoutPriorityDefaultHigh, for: .horizontal)
        titleTextField.delegate = self
        titleTextField.addTarget(self, action: #selector(change(textField:)), for: .editingChanged)
        titleTextField.setContentHuggingPriority(UILayoutPriorityDefaultLow, for: .horizontal)
        titleTextField.setContentCompressionResistancePriority(UILayoutPriorityDefaultLow, for: .horizontal)
        titleTextField.font = UIFont.systemFont(ofSize: 16)
        titleTextField.autocapitalizationType = .none
        titleTextField.returnKeyType = .next
        contentTextView.setContentHuggingPriority(UILayoutPriorityDefaultLow, for: .vertical)
        contentTextView.setContentCompressionResistancePriority(UILayoutPriorityDefaultLow, for: .vertical)
        contentTextView.font = UIFont.preferredFont(forTextStyle: .body)
        contentTextView.autocapitalizationType = .sentences
        contentTextView.backgroundColor = UIColor.lightGray.withAlphaComponent(0.1)
        contentTextView.layer.cornerRadius = cornerRadius
        contentTextView.layer.masksToBounds = true
        countLabel.text = "0"
        countLabel.font = UIFont.systemFont(ofSize: 16)
        countLabel.setContentHuggingPriority(UILayoutPriorityDefaultHigh, for: .horizontal)
        countLabel.setContentCompressionResistancePriority(UILayoutPriorityDefaultHigh, for: .horizontal)
        
        doneButton = UIBarButtonItem(barButtonSystemItem: .done,
                                     target: self,
                                     action: #selector(done(sender:)))
        doneButton?.isEnabled = false
        navigationItem.rightBarButtonItem = doneButton
        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel,
                                                           target: self,
                                                           action: #selector(cancel(sender:)))
        
        view.addSubview(titleHintLabel)
        view.addSubview(titleTextField)
        view.addSubview(countLabel)
        view.addSubview(contentTextView)
        
        titleHintLabel.snp.makeConstraints { (make) in
            make.leading.equalTo(view.snp.leadingMargin)
            make.top.equalTo(topLayoutGuide.snp.bottom).offset(5)
            make.width.equalTo(38)
            make.height.equalTo(20)
        }
        titleTextField.snp.makeConstraints { (make) in
            make.height.equalTo(titleHintLabel.snp.height)
            make.leading.equalTo(titleHintLabel.snp.trailing).offset(5)
            make.lastBaseline.equalTo(titleHintLabel.snp.lastBaseline)
        }
        countLabel.snp.makeConstraints { (make) in
            make.height.equalTo(titleTextField.snp.height)
            make.lastBaseline.equalTo(titleTextField.snp.lastBaseline)
            make.trailing.equalTo(view.snp.trailingMargin)
            make.leading.equalTo(titleTextField.snp.trailing).offset(5)
        }
        contentTextView.snp.makeConstraints { (make) in
            make.leading.equalTo(titleHintLabel)
            make.trailing.equalTo(countLabel)
            self.keyboardHeight = make.bottom.equalTo(bottomLayoutGuide.snp.top).offset(-5).constraint
            make.top.equalTo(countLabel.snp.bottom).offset(5)
        }
        
        if !replyByMail { //发送邮件时，不支持添加附件
            let addPhoto = UIBarButtonItem(barButtonSystemItem: .camera,
                                           target: self,
                                           action: #selector(addPhoto(sender:)))
            navigationItem.rightBarButtonItems?.append(addPhoto)
        }
        if replyMode {
            handleReplyMode()
            contentTextView.becomeFirstResponder()
            contentTextView.selectedRange = NSMakeRange(0, 0)
        } else {
            titleTextField.becomeFirstResponder()
        }
        updateColor()
    }
    
    func updateColor() {
        view.backgroundColor = AppTheme.shared.backgroundColor
        titleHintLabel.textColor = AppTheme.shared.backgroundColor
        titleHintLabel.backgroundColor = AppTheme.shared.lightTextColor
        countLabel.textColor = AppTheme.shared.lightTextColor
        titleTextField.textColor = AppTheme.shared.lightTextColor
        titleTextField.attributedPlaceholder = NSAttributedString(string: "添加标题",
                                                                  attributes: [NSForegroundColorAttributeName: AppTheme.shared.lightTextColor.withAlphaComponent(0.6)])
        titleTextField.keyboardAppearance = setting.nightMode ? UIKeyboardAppearance.dark : UIKeyboardAppearance.default
        contentTextView.textColor = AppTheme.shared.textColor
        contentTextView.keyboardAppearance = setting.nightMode ? UIKeyboardAppearance.dark : UIKeyboardAppearance.default
    }
    
    @objc private func nightModeChanged(_ notification: Notification) {
        updateColor()
    }
    
    func cancel(sender: UIBarButtonItem) {
        presentingViewController?.dismiss(animated: true, completion: nil)
    }
    
    func done(sender: UIBarButtonItem) {
        if let boardID = self.boardID {
            networkActivityIndicatorStart(withHUD: true)
            setEditable(false)
            DispatchQueue.global().async {
                var attachmentUploadSuccessFul = true
                if let image = self.attachedImage {
                    attachmentUploadSuccessFul = self.api.uploadAttImage(image: image)
                }
                
                var content = self.articleContent!
                if content.hasSuffix("\n") {
                    content = content + self.signature
                } else {
                    content = content + "\n" + self.signature
                }
                if self.replyMode {
                    if self.replyByMail {
                        let result = self.api.sendMailTo(user: self.originalArticle!.authorID, withTitle: self.articleTitle!, content: content)
                        print("send mail done. ret = \(result)")
                    } else {
                        let result = self.api.replyArticle(articleID: self.originalArticle!.id, title: self.articleTitle!, content: content, inBoard: boardID)
                        print("reply article done. ret = \(result)")
                    }
                } else {
                    let result = self.api.postArticle(title: self.articleTitle!, content: content, inBoard: boardID)
                    print("post article done. ret = \(result)")
                }
                DispatchQueue.main.async {
                    networkActivityIndicatorStop(withHUD: true)
                    if self.api.errorCode == 0 {
                        if attachmentUploadSuccessFul {
                            SVProgressHUD.showSuccess(withStatus: self.replyMode ? "回复成功":"发表成功")
                        } else {
                            SVProgressHUD.showError(withStatus: "附件上传失败")
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                            self.delegate?.articleDidPosted()
                            self.presentingViewController?.dismiss(animated: true, completion: nil)
                        }
                    } else if let errorDescription = self.api.errorDescription {
                        if errorDescription != "" {
                            SVProgressHUD.showInfo(withStatus: errorDescription)
                        } else {
                            SVProgressHUD.showError(withStatus: "出错了")
                        }
                        self.setEditable(true)
                    } else {
                        SVProgressHUD.showError(withStatus: "出错了")
                        self.setEditable(true)
                    }
                }
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(keyboardWillShow(notification:)),
                                               name: .UIKeyboardWillChangeFrame,
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(nightModeChanged(_:)),
                                               name: AppTheme.kAppThemeChangedNotification,
                                               object: nil)
        api.resetStatus() //发文/回复文章时，必须手动resetStatus，因为中间可能会有添加附件等操作
        setupUI()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        view.endEditing(true)
    }
    
    func addPhoto(sender: UIBarButtonItem) {
        if attachedImage == nil {
            let actionSheet = UIAlertController(title: "添加照片", message: nil, preferredStyle: .actionSheet)
            if UIImagePickerController.isSourceTypeAvailable(.photoLibrary) {
                let camera = UIAlertAction(title: "从图库中选择", style: .default) { [unowned self] action in
                    let picker = UIImagePickerController()
                    picker.delegate = self
                    picker.sourceType = .photoLibrary
                    picker.modalPresentationStyle = .formSheet
                    self.present(picker, animated: true, completion: nil)
                }
                actionSheet.addAction(camera)
            }
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                let camera = UIAlertAction(title: "使用相机拍照", style: .default) { [unowned self] action in
                    let picker = UIImagePickerController()
                    picker.delegate = self
                    picker.sourceType = .camera
                    self.present(picker, animated: true, completion: nil)
                }
                actionSheet.addAction(camera)
            }
            actionSheet.addAction(UIAlertAction(title: "取消", style: .cancel, handler: nil))
            actionSheet.popoverPresentationController?.barButtonItem = sender
            present(actionSheet, animated: true, completion: nil)
        } else {
            let alert = UIAlertController(title: "是否删除图片附件？", message: nil, preferredStyle: .alert)
            let deleteAction = UIAlertAction(title: "删除", style: .destructive)  { [unowned self] action in
                self.attachedImage = nil
            }
            alert.addAction(deleteAction)
            alert.addAction(UIAlertAction(title: "取消", style: .cancel, handler: nil))
            present(alert, animated: true, completion: nil)
        }
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        dismiss(animated: true, completion: nil)
        let type = info[UIImagePickerControllerMediaType] as! String
        if type == kUTTypeImage as String {
            attachedImage = info[UIImagePickerControllerOriginalImage] as? UIImage
        }
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        dismiss(animated: true, completion: nil)
    }
    
    func handleReplyMode() {
        title = replyByMail ? "邮件回复" : "回复文章"
        doneButton?.isEnabled = true
        if let article = originalArticle {
            // 处理标题
            if article.subject.lowercased().hasPrefix("re:") {
                articleTitle = article.subject
            } else {
                articleTitle = "Re: " + article.subject
            }
            countLabel.text = "\((articleTitle!).characters.count)"
            // 处理内容
            var tempContent = "\n【 在 \(article.authorID) 的大作中提到: 】\n"
            var origContent = article.body + "\n"
            
            if let range = origContent.range(of: signature) {
                origContent.replaceSubrange(range, with: "")
            }
            
            for _ in 1...3 {
                if let linebreak = origContent.range(of: "\n") {
                    tempContent += (": " + origContent.substring(to: linebreak.upperBound))
                    origContent = origContent.substring(from: linebreak.upperBound)
                } else {
                    break
                }
            }
            if origContent.range(of: "\n") != nil {
                tempContent += ": ....................\n"
            }
            
            articleContent = tempContent
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    func keyboardWillShow(notification: Notification) {
        let info = notification.userInfo
        let animationDuration = info?[UIKeyboardAnimationDurationUserInfoKey] as! Double
        var keyboardFrame = info?[UIKeyboardFrameEndUserInfoKey] as! CGRect
        keyboardFrame = view.convert(keyboardFrame, from: view.window)
        let height = keyboardFrame.size.height
        keyboardHeight?.update(offset: -height - 5)
        UIView.animate(withDuration: animationDuration, animations: { () -> Void in
            self.view.layoutIfNeeded()
        })
        
    }
    
    //MARK: - UITextFieldDelegate
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        contentTextView.becomeFirstResponder()
        return false
    }
    
    func change(textField: UITextField) {
        if let length = textField.text?.characters.count {
            countLabel.text = "\(length)"
            if length > 0 {
                doneButton?.isEnabled = true
            } else {
                doneButton?.isEnabled = false
            }
        }
    }
}

protocol ComposeArticleControllerDelegate: class {
    func articleDidPosted()
}
