//
//  ObjectInfoTableViewCell.swift
//  Indoor Blueprint
//
//  Created by Nijel Hunt on 10/3/22.
//

import UIKit

class ObjectInfoTableViewCell: UITableViewCell {

    var user: User!
    var model: Model!
    
    static let identifier = "ObjectInfoTableViewCell"
 
    
    private let objectTypeLabel: UILabel = {
        let label = UILabel(frame: CGRect(x: 20, y: 54.5, width: 250, height: 17))
        label.numberOfLines = 1
        label.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        label.textColor = .darkGray
        return label
    }()
    
    private let creditsImage: UIImageView = {
        let imageView = UIImageView(frame: CGRect(x: 20, y: 79.5, width: 16, height: 16))
        imageView.contentMode = .scaleAspectFit
        imageView.tintColor = .systemYellow
        imageView.clipsToBounds = true
        return imageView
    }()
    
    private let priceLabel: UILabel = {
        let label = UILabel(frame: CGRect(x: 20, y: 79, width: 250, height: 17))
        label.numberOfLines = 1
        label.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        label.textColor = .darkGray
        return label
    }()
    
    private let objectNameLabel: UILabel = {
        let label = UILabel(frame: CGRect(x: 20, y: 20, width: 350, height: 30.5))
        label.numberOfLines = 1
        label.font = UIFont.systemFont(ofSize: 25, weight: .bold)
        label.textColor = .label
        return label
    }()
    
    let hostLabel: UILabel = {
        let label = UILabel(frame: CGRect(x: UIScreen.main.bounds.width - 103, y: 54.5, width: 83, height: 17.5))
        label.numberOfLines = 1
        label.textAlignment = .right
        label.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        label.textColor = .darkGray // UIColor(red: 73/255, green: 73/255, blue: 73/255, alpha: 1.0)
        label.isUserInteractionEnabled = true
        return label
    }()
    
    private let objectIdentifierLabel: UILabel = {
        let label = UILabel(frame: CGRect(x: 20, y: 124, width: 95, height: 27))
        label.numberOfLines = 1
        label.textAlignment = .center
        label.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        label.textColor = .systemGray3 // UIColor(red: 73/255, green: 73/255, blue: 73/255, alpha: 1.0)
        label.backgroundColor = .systemGray6
        return label
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
        if UITraitCollection.current.userInterfaceStyle == .light {
//            backgroundColor = UIColor(red: 241/255, green: 244/255, blue: 244/255, alpha: 1.0)
//            contentView.backgroundColor = UIColor(red: 241/255, green: 244/255, blue: 244/255, alpha: 1.0)
        } else {
            backgroundColor = UIColor(red: 34/255, green: 34/255, blue: 34/255, alpha: 1.0)
            contentView.backgroundColor = UIColor(red: 34/255, green: 34/255, blue: 34/255, alpha: 1.0)
        }
        contentView.addSubview(objectIdentifierLabel)
        contentView.addSubview(objectNameLabel)
        contentView.addSubview(hostLabel)
        contentView.addSubview(creditsImage)
        contentView.addSubview(priceLabel)
        contentView.addSubview(objectTypeLabel)
    }
    
//    override func prepareForReuse() {
//        super.prepareForReuse()
////        objectNameLabel.text = nil
////        priceLabel.text = nil
////        hostLabel.text = nil
////        objectIdentifierLabel.text = nil
////        objectTypeLabel.text = nil
//    }
//
//    override func layoutSubviews() {
//        super.layoutSubviews()
//      //  priceLabel.sizeToFit()
//     //   hostLabel.sizeToFit()
//    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }
    
    public func configure(with modelId: String) {
        FirestoreManager.getModel(modelId) { model in
            //let id = model?.id
            let price = model?.price ?? 0
            if price == 0 {
                self.priceLabel.text = "FREE"
            } else {
                self.creditsImage.image = UIImage(systemName: "diamond.fill")
                self.priceLabel.frame =  CGRect(x: 39.5, y: 79, width: 250, height: 17)
                self.priceLabel.text = "\(model?.price ?? 0)"
            }
            print(self.priceLabel.text)
            self.objectNameLabel.text = model?.name
          //  self.hostLabel.text = model?.creatorId
            let id = model?.id
            self.objectIdentifierLabel.text = "90320097" // model?.id
            self.objectTypeLabel.text = model?.category
            //let creator = model?.creatorId

            if self.priceLabel.text == "" || self.priceLabel.text == "$" {
                self.priceLabel.text = "FREE"
            }
            if model?.creatorId != nil || model?.creatorId != ""{
                FirestoreManager.getUser(model?.creatorId ?? "1zMDe5Raoee3At3jjFdjVVRqbIt2") { user in
                    let name = user?.name
                    print("\(name) is name")
                    let username = user?.username
                    if name != nil && name != "" && name != "Optional(\(""))"{
                        self.hostLabel.text = "by \(name ?? "")"
                    } else {
                        self.hostLabel.text = "by \(username ?? "")"
                    }
                }
            }
            if self.hostLabel.text == "" {
                self.hostLabel.text = "by Nijel Hunt"
            }
        }
    }

}
