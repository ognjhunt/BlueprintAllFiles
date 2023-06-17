//
//  NetworkConnectionTableViewCell.swift
//  Indoor Blueprint
//
//  Created by Nijel Hunt on 10/4/22.
//

import UIKit

class NetworkConnectionTableViewCell: UITableViewCell {
    
    static let identifier = "NetworkConnectionTableViewCell"
    
    
    private let label: UILabel = {
        let label = UILabel(frame: CGRect(x: 56, y: 16, width: 180, height: 23))
        label.numberOfLines = 1
        label.font = UIFont.systemFont(ofSize: 19, weight: .medium)
        label.textColor = .label
        label.text = "Find Blueprints"
        return label
    }()
    
    let connectionSwitch: UISwitch = {
        let connect = UISwitch(frame: CGRect(x: UIScreen.main.bounds.width - 72, y: 12, width: 51, height: 31))
        connect.isOn = true
        return connect
    }()

    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    required init?(coder: NSCoder) {
        fatalError()
    }
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        clipsToBounds = true
//        if UITraitCollection.current.userInterfaceStyle == .light {
//            backgroundColor = UIColor(red: 241/255, green: 244/255, blue: 244/255, alpha: 1.0)
//            contentView.backgroundColor = UIColor(red: 241/255, green: 244/255, blue: 244/255, alpha: 1.0)
//        } else {
//            backgroundColor = UIColor(red: 34/255, green: 34/255, blue: 34/255, alpha: 1.0)
//            contentView.backgroundColor = UIColor(red: 34/255, green: 34/255, blue: 34/255, alpha: 1.0)
//        }

        contentView.addSubview(connectionSwitch)
        contentView.addSubview(label)
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
      //  connectionSwitch = nil
      //  label.text = nil
    }

    override func layoutSubviews() {
        super.layoutSubviews()
    }
    
    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

}
