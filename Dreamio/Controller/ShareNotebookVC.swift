//
//  ShareNotebookVC.swift
//  Dreamio
//
//  Created by Bhavesh patel on 9/18/20.
//  Copyright © 2020 Bold Lion. All rights reserved.
//

import UIKit
import SCLAlertView
import FirebaseDatabase
import Firebase

protocol ShareNotebookVCDelegate: AnyObject {
    func refetchNotebooks()
}

class ShareNotebookVC: UIViewController {

    @IBOutlet weak var containerView: UIView!
    @IBOutlet weak var headerView: UIView!
    @IBOutlet weak var titleTextField: UITextField!
    @IBOutlet weak var cancelButton: UIButton!
    @IBOutlet weak var saveButton: UIButton!
    
    weak var delegate: ShareNotebookVCDelegate?
    var notebookId: String?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupTextFieldDelegates()
        handleTextField()
        // Do any additional setup after loading the view.
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        setUI()
    }

    func postNotificationNotebookWith(uid: String, newTitle: String) {
        // POST NOTIFICATION
        let name = Notification.Name(rawValue: NotificationKey.notebookRenamed)
        let dict = ["uid" : uid, "title": newTitle]
        NotificationCenter.default.post(name: name, object: nil, userInfo: dict)
    }
    
    @IBAction func saveTapped(_ sender: UIButton) {
        guard let username = titleTextField.text else { return }
        guard let id = notebookId else { return }
        view.endEditing(true)
        if title != "" {
            let REF_USERS = Database.database().reference().child(DatabaseLocation.users)
            REF_USERS.queryOrdered(byChild: "username").queryEqual(toValue: username.lowercased()).observeSingleEvent(of: .value, with:  { snapshot in
                if snapshot.exists() {
                    let uid = (snapshot.children.allObjects[0] as! DataSnapshot).key
                    let REF_USER_NOTEBOOKS = Database.database().reference().child(DatabaseLocation.user_notebooks)
                    REF_USER_NOTEBOOKS.child(uid).child(id).setValue(true, withCompletionBlock: { error, _ in
                        if error != nil {
                            SCLAlertView().showError("Error!", subTitle: error.debugDescription)
                        }
                        else {
                            SCLAlertView().showSuccess("Success!", subTitle: "Notebook Successfully shared!")
                            self.dismiss(animated: true)
                        }
                    })
                    return
                }
                else {
                    SCLAlertView().showError("Error!", subTitle: "Username not exists!")
                }
            })
//            Api.Notebooks.renameNotebook(withId: id, title: title, onSuccess: { [unowned self] in
//                SCLAlertView().showSuccess("Success!", subTitle: "Notebook Successfully Renamed!")
//                self.postNotificationNotebookWith(uid: id, newTitle: title)
//                self.delegate?.refetchNotebooks()
//                self.dismiss(animated: true)
//            }, onError: { error in
//                SCLAlertView().showError("Error!", subTitle: error)
//            })
        }
    }
    
    @IBAction func cancelTapped(_ sender: UIButton) {
        dismiss(animated: true)
    }
    
    func setUI() {
        DispatchQueue.global().async {
            DispatchQueue.main.async {
                self.containerView.layer.cornerRadius = 10
                self.containerView.clipsToBounds = true
                self.headerView.clipsToBounds = true
                self.headerView.setGradientBackground(colorOne: Colors.purpleDarker, colorTwo: Colors.purpleLight)
            }
        }
    }
    
    deinit {
        print("RenameNotebookVC deinit")
    }
}
extension ShareNotebookVC: UITextFieldDelegate {
    
    func setupTextFieldDelegates() {
        titleTextField.delegate = self
        saveButton.isEnabled = false
    }
    
    func handleTextField() {
        titleTextField.addTarget(self, action: #selector(textfieldDidChange), for: .editingChanged)
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
    
    @objc func textfieldDidChange () {
        guard let title = titleTextField.text, !title.isEmpty
            else {
                saveButton.isEnabled = false
                return
        }
        saveButton.isEnabled = true
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        view.endEditing(true)
    }
}
