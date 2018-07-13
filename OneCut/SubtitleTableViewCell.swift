//
//  SubtitleTableViewCell.swift
//  OneCut
//
//  Created by zpc on 2018/7/12.
//  Copyright © 2018年 zpc. All rights reserved.
//

import UIKit

class SubtitleTableViewCell: UITableViewCell {

    @IBOutlet weak var timeTextField: UITextField!
    
    @IBOutlet weak var subtitleTextField: UITextField!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

}
