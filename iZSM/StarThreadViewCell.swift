//
//  StarThreadViewCell.swift
//  iZSM
//
//  Created by Naitong Yu on 2019/9/28.
//  Copyright © 2019 Naitong Yu. All rights reserved.
//

import UIKit
import SnapKit

class StarThreadViewCell: UITableViewCell {
    
    var title: String?
    var boardID: String?
    var authorID: String?
    var comment: String?

    private let setting = AppSetting.shared
    private let titleLabel = UILabel()
    private let boardLabel = NTLabel()
    private let userIDLabel = UILabel()
    private let commentLabel = UILabel()
    
    var offset: Constraint?
    
    func set(title: String?, boardID: String?, authorID: String?, comment: String?) {
        self.title = title
        self.boardID = boardID
        self.authorID = authorID
        self.comment = comment
        updateUI()
    }
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setupUI()
    }
    
    /// Setup constraints
    private func setupUI() {
        titleLabel.numberOfLines = 0
        boardLabel.lineBreakMode = .byClipping
        
        contentView.addSubview(titleLabel)
        contentView.addSubview(boardLabel)
        contentView.addSubview(userIDLabel)
        contentView.addSubview(commentLabel)
                
        
        boardLabel.snp.makeConstraints { (make) in
            make.leading.equalTo(contentView.snp.leadingMargin)
            make.top.equalTo(contentView.snp.topMargin)
            make.trailing.equalTo(userIDLabel.snp.leading)
        }
        userIDLabel.snp.makeConstraints { (make) in
            make.lastBaseline.equalTo(boardLabel)
            make.trailing.lessThanOrEqualTo(contentView.snp.trailingMargin)
        }
        titleLabel.snp.makeConstraints { (make) in
            make.leading.equalTo(boardLabel)
            make.trailing.lessThanOrEqualTo(contentView.snp.trailingMargin)
            make.top.equalTo(boardLabel.snp.bottom).offset(5)
        }
        commentLabel.snp.makeConstraints { (make) in
            self.offset = make.top.equalTo(titleLabel.snp.bottom).offset(5).constraint
            make.leading.equalTo(boardLabel)
            make.trailing.lessThanOrEqualTo(contentView.snp.trailingMargin)
            make.bottom.equalTo(contentView.snp.bottomMargin)
        }
    }
    
    /// Update font size and color
    private func updateUI() {
        if let title = title, let boardID = boardID, let authorID = authorID {
            titleLabel.text = title
            boardLabel.text = boardID
            let titleDescriptor = UIFontDescriptor.preferredFontDescriptor(withTextStyle: .headline)
            titleLabel.font = UIFont.boldSystemFont(ofSize: titleDescriptor.pointSize * setting.smallFontScale)
            let infoDescriptor = UIFontDescriptor.preferredFontDescriptor(withTextStyle: .footnote)
            let normalInfoFont = UIFont.systemFont(ofSize: infoDescriptor.pointSize * setting.smallFontScale)
            let boldInfoFont = UIFont.boldSystemFont(ofSize: infoDescriptor.pointSize * setting.smallFontScale)
            let normalAttributes: [NSAttributedString.Key : Any] = [.font: normalInfoFont, .foregroundColor: UIColor.secondaryLabel]
            let userIDAttributes: [NSAttributedString.Key : Any] = [.font: boldInfoFont, .foregroundColor: UIColor.secondaryLabel]
            let attributedText = NSMutableAttributedString(string: " • ", attributes: normalAttributes)
            attributedText.append(NSAttributedString(string: authorID, attributes: userIDAttributes))
            userIDLabel.attributedText = attributedText
            if let comment = comment {
                commentLabel.attributedText = NSAttributedString(string: comment, attributes: normalAttributes)
                offset?.update(offset: 5)
            } else {
                commentLabel.text = nil
                offset?.update(offset: 0)
            }
            
            let paddingWidth = infoDescriptor.pointSize * setting.smallFontScale / 2
            boardLabel.contentInsets = UIEdgeInsets(top: 0, left: paddingWidth, bottom: 0, right: paddingWidth)
            boardLabel.clipsToBounds = true
            boardLabel.layer.cornerRadius = paddingWidth / 2
            boardLabel.textColor = UIColor.secondaryLabel
            boardLabel.font = normalInfoFont
            boardLabel.backgroundColor = UIColor.secondarySystemFill
            titleLabel.textColor = UIColor(named: "MainText")
        } else {
            titleLabel.text = nil
            boardLabel.text = nil
            userIDLabel.text = nil
            commentLabel.text = nil
        }
    }
}
