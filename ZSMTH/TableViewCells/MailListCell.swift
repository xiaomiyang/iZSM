//
//  MailListCell.swift
//  ZSMTH
//
//  Created by Naitong Yu on 15/3/19.
//  Copyright (c) 2015 Naitong Yu. All rights reserved.
//

import UIKit

private var formatter = NSDateFormatter()

class MailListCell: UITableViewCell {

    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var authorLabel: UILabel!
    @IBOutlet weak var timeLabel: UILabel!
    @IBOutlet weak var unreadLabel: UILabel!

    var mail: SMMail? {
        didSet {
            if let mail = self.mail {
                titleLabel?.text = mail.subject
                authorLabel?.text = mail.authorID
                timeLabel?.text = stringFromDate(mail.time)

                if mail.flags.hasPrefix("N") {
                    unreadLabel?.hidden = false
                } else {
                    unreadLabel?.hidden = true
                }

                let descriptor = UIFontDescriptor.preferredFontDescriptorWithTextStyle(UIFontTextStyleSubheadline)
                titleLabel?.font = UIFont.boldSystemFontOfSize(descriptor.pointSize)
                timeLabel?.font = UIFont.preferredFontForTextStyle(UIFontTextStyleFootnote)
                authorLabel?.font = UIFont.preferredFontForTextStyle(UIFontTextStyleFootnote)
            }
        }
    }


    private func stringFromDate(date: NSDate) -> String {
        var timeInterval = Int(date.timeIntervalSinceNow)
        if timeInterval >= 0 {
            return "现在"
        }

        timeInterval = -timeInterval
        if timeInterval < 60 {
            return "\(timeInterval)秒前"
        }
        timeInterval /= 60
        if timeInterval < 60 {
            return "\(timeInterval)分钟前"
        }
        timeInterval /= 60
        if timeInterval < 24 {
            return "\(timeInterval)小时前"
        }
        timeInterval /= 24
        if timeInterval < 7 {
            return "\(timeInterval)天前"
        }
        if timeInterval < 30 {
            return "\(timeInterval/7)周前"
        }
        if timeInterval < 365 {
            return "\(timeInterval/30)个月前"
        }
        timeInterval /= 365
        return "\(timeInterval)年前"
    }

}
