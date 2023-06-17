//
//  ContentNameTableViewCell.swift
//  Indoor Blueprint
//
//  Created by Nijel Hunt on 1/5/23.
//

import UIKit

class ContentNameTableViewCell: UITableViewCell {

    // Declare the model property
    var model: Model!
    
    // Declare a static constant for the identifier
    static let identifier = "contentNameCell"
    
    // Declare a private nameLabel property
    private let nameLabel: UILabel = {
        let label = UILabel(frame: CGRect(x: 20, y: 11, width: 45, height: 20))
        // Set number of lines to 1
        label.numberOfLines = 1
        // Set the label text
        label.text = "Name"
        // Set the font and weight
        label.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        // Set the text color
        label.textColor = .black
        return label
    }()
    
    // Declare a nameTextField property
    let nameTextField: UITextField = {
        let textField = UITextField(frame: CGRect(x: 20, y: 41, width: UIScreen.main.bounds.width - 40, height: 40))
        // Set the font
        textField.font = UIFont.systemFont(ofSize: 16)
        // Set the placeholder text
        textField.placeholder = "Item Name"
        // Set the autocapitalization type
        textField.autocapitalizationType = .sentences
        // Enable user interaction
        textField.isUserInteractionEnabled = true
        // Set the border style
        textField.borderStyle = .roundedRect
        // Add padding to the left of the text field
        let paddingView = UIView(frame: CGRectMake(0, 0, 4, textField.frame.height))
        textField.leftView = paddingView
        textField.leftViewMode = UITextField.ViewMode.always
        return textField
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
        // Add the nameLabel and nameTextField as subviews
        contentView.addSubview(nameLabel)
        contentView.addSubview(nameTextField)
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }
}

