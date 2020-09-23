//
//  NewEntryVC.swift
//  Dreamio
//
//  Created by Bold Lion on 4.03.19.
//  Copyright © 2019 Bold Lion. All rights reserved.
//

import UIKit
import SCLAlertView
import WSTagsField
import TagListView
import Firebase
import MobileCoreServices
import IDMPhotoBrowser
import FirebaseStorage
import Firebase
import FirebaseAuth
import FirebaseDatabase

protocol NewEntrtVCDelegate: AnyObject {
    func fetchNewEntryWith(id: String)
}

class NewEntryVC: UIViewController, UITextFieldDelegate,TagListViewDelegate,IDMPhotoBrowserDelegate {
    @IBOutlet weak var entryContentUITextView: UITextView!
    @IBOutlet weak var scrVIew: UIScrollView!
//    @IBOutlet weak var suggestedHeight: NSLayoutConstraint!
    @IBOutlet weak var collVIew: UICollectionView!
    
    @IBOutlet weak var suggestedTag: TagListView!
    @IBOutlet weak var userTags: WSTagsField!
    @IBOutlet weak var entryTitleTextView: CustomSearchTextField!
    @IBOutlet weak var titleHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var saveButton: UIBarButtonItem!
    private var alertController: UIAlertController?
   // @IBOutlet weak var contentBottomConstraint: NSLayoutConstraint!
    var tags: [String] = ["Beautiful day","nice photo","gorgeous","appealing"]
    var titlePlaceholder : UILabel!
    var contentPlaceholder: UILabel!
    var notebookId: String?
    var entry: Entry?
    var entryId: String?
    lazy var labels: [String] = {
        let labels = [String]()
        return labels
    }()
    var hasLabels = false
    var updatedLabels: [String]?
    var ref: DatabaseReference!
    weak var delegate: NewEntrtVCDelegate?
    
    var oldTags = [String]()
    var entryImage = [URL]()
    
    let picker = UIImagePickerController()
    var popOver: UIPopoverController!
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        ref = Database.database().reference()
        picker.delegate = self
        ref.child("tag").observe(.value, with: { (snapshot) in
            print(snapshot)
            if let dic = snapshot.value as? NSDictionary{
                self.tags = dic.allKeys as! [String]
                self.suggestedTag.addTags(self.tags)
                self.suggestedTag.frame = CGRect(x: 0, y: 0, width: self.suggestedTag.intrinsicContentSize.width, height: self.suggestedTag.intrinsicContentSize.height)
                self.scrVIew.contentSize = self.suggestedTag.intrinsicContentSize
            }
            self.populateEntryFields()
        })
        collVIew.delegate = self
        collVIew.dataSource = self
        var dataArray : [String] = []
        if  let path = Bundle.main.path(forResource: "strains", ofType: "csv")
        {
            dataArray = []
            let url = URL(fileURLWithPath: path)
            do {
                let data = try Data(contentsOf: url)
                let dataEncoded = String(data: data, encoding: .utf8)
                if  let dataArr = dataEncoded?.components(separatedBy: "\r\n").map({ $0.components(separatedBy: ";") })
                {
                    for line in dataArr
                    {
                        dataArray.append(contentsOf: line)
                    }
                }
                entryTitleTextView.dataList = dataArray
                self.tags = dataArray
            }
            catch let jsonErr {
               print("\n Error read CSV file: \n ", jsonErr)
            }
        }
        
        DispatchQueue.global().async {
            DispatchQueue.main.async {
                
            }
        }
        
        saveButton.isEnabled = false
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide), name: UIResponder.keyboardWillHideNotification, object: nil)
        

        userTags.placeholderAlwaysVisible = true
        userTags.font = UIFont.init(name: "HelveticaNeue-Regular", size: 15)

        userTags.contentInset = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        userTags.layoutMargins = UIEdgeInsets(top: 2, left: 6, bottom: 2, right: 6)

        userTags.tintColor = Colors.purpleDarker
        userTags.textColor = .white
        userTags.textField.textColor = .black
        userTags.selectedColor = .lightGray
        userTags.selectedTextColor = .darkGray
        userTags.placeholderColor = Colors.purpleDarker
        userTags.placeholderAlwaysVisible = true
        userTags.textField.returnKeyType = .next
        //userTags.textField.keyboardType = .twitter
        userTags.numberOfLines = 8
        userTags.enableScrolling = true
        
        userTags.onDidAddTag = { field, tag in
            self.saveButton.isEnabled = true
        }
        
        userTags.onDidRemoveTag = { field, tag in
            self.saveButton.isEnabled = true
        }
        
        suggestedTag.delegate = self
        suggestedTag.textFont = .systemFont(ofSize: 15)!
        suggestedTag.shadowRadius = 2
        suggestedTag.shadowOpacity = 0.4
        suggestedTag.shadowColor = UIColor.black
        suggestedTag.shadowOffset = CGSize(width: 1, height: 1)
        suggestedTag.alignment = .left
        
        
        //Looks for single or multiple taps.
        let tap: UITapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        view.addGestureRecognizer(tap)
    }
    
    // MARK: TagListViewDelegate
    func tagPressed(_ title: String, tagView: TagView, sender: TagListView) {
        print("Tag pressed: \(title), \(sender)")
        tagView.isSelected = !tagView.isSelected
        if tagView.isSelected{
            self.userTags.addTag(title)
        }else{
            self.userTags.removeTag(title)
        }
    }

    func tagRemoveButtonPressed(_ title: String, tagView: TagView, sender: TagListView) {
       print("Tag Remove pressed: \(title), \(sender)")
       sender.removeTagView(tagView)
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        NavBar.setGradientNavigationBar(for: navigationController)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        tabBarController?.tabBar.isHidden = false
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        createToolbar()
        setTextViewsDelegates()
    
    }
    
    func populateEntryFields() {
        if let uid = entryId {
            fetchEntryWith(uid: uid)
        }
        if let title = entry?.title, let content = entry?.content {
            entryTitleTextView.text = title
            entryContentUITextView.text = content
           
            setupTitleTextViewPlaceholder()
            setupContentTextViewPlaceholder()
            //textViewDidChange(entryTitleTextView)
            textViewDidChange(entryContentUITextView)
            navigationItem.title = "Edit & View Entry"
        }
        if let entryUid = entry?.id {
            fetchLabelsForEntryWith(uid: entryUid)
        }
        
        if let urls = entry?.photoUrls{
            if urls.count > 0{
                self.entryImage.removeAll()
                for i in urls{
                    self.entryImage.append(URL(string: i)!)
                }
            }
            self.collVIew.reloadData()
        }
    }
    
    func fetchLabelsForEntryWith(uid: String) {
        Api.Entry_Labels.fetchAllLabelsForEntryWith(uid: uid,
            onSuccess: { [unowned self] labels in
                self.labels = labels
                self.createToolbar()
                self.userTags.addTags(labels)
                self.oldTags = labels
                for i in self.suggestedTag.tagViews{
                    if self.oldTags.contains(i.titleLabel!.text!) {
                        i.isSelected = true
                    }
                }
            }, onNoLabels: { [unowned self] in
                self.labels = []
                self.createToolbar()
            }, onError: { errorMessage in
                 SCLAlertView().showError("Error", subTitle: errorMessage)
        })
    }
    
    func fetchEntryWith(uid: String) {
        Api.Entries.fetchEntryWith(uid: uid,
            onSuccess: { [unowned self] entry in
                self.entry = entry
                self.entryId = nil
                self.populateEntryFields() },
            onError: { errorMessage in
                SCLAlertView().showError("Error", subTitle: errorMessage)
        })
    }
    
    func createToolbar() {
        let toolBar = UIToolbar()
        toolBar.sizeToFit()
        toolBar.barTintColor = .white
        toolBar.tintColor = Colors.purpleDarker
        
        let doneButton = UIBarButtonItem(title: "Done", style: .done, target: self, action: #selector(dismissKeyboard))
        let flexibleSpace = UIBarButtonItem(barButtonSystemItem: UIBarButtonItem.SystemItem.flexibleSpace, target: nil, action: nil)
        
//        var imageName = ""
//
//        if let updated = updatedLabels {
//            imageName = updated.count > 0 ? "label_selected" :  "label_empty"
//        }
//        else {
//            imageName = labels.count > 0 ? "label_selected" : "label_empty"
//        }
//
//        let labelButton = UIBarButtonItem(image: UIImage(named: imageName), style: .plain, target: self, action: #selector(goToLabelsVC))
        toolBar.isUserInteractionEnabled = true
        toolBar.items = [ flexibleSpace, doneButton]//labelButton
        entryTitleTextView.inputAccessoryView = toolBar
        entryContentUITextView.inputAccessoryView = toolBar
    }
    
    @objc func dismissKeyboard() {
        view.endEditing(true)
    }
    
    @objc func goToLabelsVC() {
        view.endEditing(true)
        var labelsToSend = [String]()
        if let updated = updatedLabels, updated.count >= 0 {
            labelsToSend = updated
        }
        else {
            labelsToSend = labels
        }
        performSegue(withIdentifier: Segues.NewEntryToLabelsVC, sender: labelsToSend)
    }
    
    @objc func keyboardWillShow(notification: Notification) {
        if ((notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue) != nil {
            UIView.animate(withDuration: 0.2, animations: { [unowned self] in
               // self.contentBottomConstraint.constant = keyboardSize.height
                self.view.layoutIfNeeded()
            })
        }
    }
    @objc func keyboardWillHide(notification: Notification) {
        UIView.animate(withDuration: 0.2, animations: { [unowned self] in
           // self.contentBottomConstraint.constant = 20
            self.view.layoutIfNeeded()
        })
    }
    
    @IBAction func cancelTapped(_ sender: UIBarButtonItem) {
        view.endEditing(true)
        if saveButton.isEnabled {
            
            Alerts.showWarningWithTwoCustomActions(title: "Wait!", subtitle: "You haven't saved your strain entry. Tap on SAVE button or dismiss it. You can always edit your entry.", dismissTitle: "Dismiss",
                dismissAction: { [unowned self]  in
                    self.clear()
                    self.dismiss(animated: true)
                },
                customAction2: {  [unowned self] in
                    self.saveEntry()
                },
                action2Title: "Save")
        }
        else {
            clear()
            dismiss(animated: true, completion: nil)
        }
    }
    
    @IBAction func saveTapped(_ sender: UIBarButtonItem) {
        saveEntry()
    }
    
    func saveEntry() {
        view.endEditing(true)
        saveButton.isEnabled = !saveButton.isEnabled
        if notebookId != nil {
            guard let title = entryTitleTextView.text else { return }
            guard let content = entryContentUITextView.text else { return }

            guard let userID = Auth.auth().currentUser?.uid else { return }
            for i in self.userTags.tags{
                //update user_labels
               self.ref.child("user_labels").child(userID).child(i.text).setValue(true)
            }
          //  self.labels = arr
            
            guard let notebId = notebookId else { return }
            if entry != nil {
                guard let entryId = entry?.id else { return }
                self.labels = self.oldTags
                var arr = [String]()
                for i in self.userTags.tags{
                    arr.append(i.text)
                }
                if let photoUrls = self.entry!.photoUrls {
                    if photoUrls.count > 0 {
                        for i in photoUrls{
                            let storage = Storage.storage()
                            let url = i
                            let storageRef = storage.reference(forURL: url)

                            //Removes image from storage
                            storageRef.delete { error in
                                if let error = error {
                                    print(error)
                                } else {
                                    // File deleted successfully
                                }
                            }
                        }
                        
                    }
                } else {  }
                //remove pic entry
                self.ref.child("entries").child(entryId).child("photoUrls").setValue([])
                self.updatedLabels = arr
                updateDreamEntry(notebookId: notebId, entryId: entryId, title: title, content: content)
            }
            else {
                createNewEntry(notebookId: notebId, title: title, content: content)
            }
           
        }
        else {
            performSegue(withIdentifier: Segues.NewEntryToSelectNotebookVC, sender: nil)
        }
    }
    
    func success(alert: SCLAlertViewResponder, entryId: String) {
        alert.close()
        self.delegate?.fetchNewEntryWith(id: entryId)
        self.clear()
        self.dismiss(animated: true)
    }
    
    func createNewEntry(notebookId: String, title: String, content: String) {
        guard let entryID = Api.Entries.REF_ENTRIES.childByAutoId().key else { return }
        let alert = SCLAlertView().showWait("Saving...", subTitle: "Please wait...")
        
        var arrcompressed = [UIImage]()

        for i in self.entryImage{
            
            if let data = try? Data(contentsOf: i)
            {
                let image: UIImage = UIImage(data: data)!
                if let imageData = image.jpegData(compressionQuality: 0.1) {
                    arrcompressed.append(UIImage(data: imageData)!)
                }
                
            }
        }
        
        guard let currentUser = Auth.auth().currentUser else {
            return
        }
        
        let currentUserId = currentUser.uid
        UploadImages.uploadImages(userId: currentUserId, imagesArray: arrcompressed) { (urls) in
            // NOTE: Entry with labels
            if self.userTags.tags.count > 0 {
                Api.Entries.saveEntry(forNotebookUid: notebookId, photoUrls: urls, entryUid: entryID, title: title, content: content,
                    onSuccess: { [unowned self]  in
    //                    Api.Labels.doesLabelExistAlready(labels: self.labels,
    //                        onExist: { label in
                                guard let userID = Auth.auth().currentUser?.uid else { return }
                                for i in self.userTags.tags{
                                    self.ref.child("labels").child(userID).child(i.text).child(entryID).setValue(true)
                                }
                                var arr = [String]()
                                for i in self.userTags.tags{
                                    arr.append(i.text)
                                }
    //
                                Api.Entry_Labels.saveEntryLabelsWith(entryUid: entryID, labels: arr,
                                    onSuccess: {
                                        Api.Entries_Timestamp.setEntryTimestampFor(notebookWith: notebookId, entryId: entryID,
                                        onSuccess: { [unowned self] in
                                            self.success(alert: alert, entryId: entryID) },
                                        onError: { [unowned self] message in
                                            self.updateErrorBlock(alert: alert, message: message) })
                                        },
                                onError: { [unowned self] message in
                                    self.updateErrorBlock(alert: alert, message: message) })
    //                            Api.Labels.addNewEntryIdForLabel(label: label, entryId: entryID,
    //                                onSuccess: {
    //                                    Api.Entry_Labels.saveEntryLabelsWith(entryUid: entryID, labels: [label],
    //                                        onSuccess: {


    //                    },
    //                                        onError: { [unowned self] message in
    //                                            self.updateErrorBlock(alert: alert, message: message)  })
    //                    },
    //                                onError: { [unowned self] message in
    //                                    self.updateErrorBlock(alert: alert, message: message) })
    //
    //                    },
    //                        onDoesntExist: { label in
    ////                            Api.Labels.addNewLabel(label: label, entryId: entryID,
    ////                                onSuccess: {
    //                            var arr = [String]()
    //                           for i in self.userTags.tags{
    //                               arr.append(i.text)
    //                           }
    //                            Api.Entry_Labels.saveEntryLabelsWith(entryUid: entryID, labels: arr,
    //                               onSuccess: {
    //                                Api.User_Labels.updateLabels(labels: [label],
    //                                   onSuccess: {
    //                                       Api.Entries_Timestamp.setEntryTimestampFor(notebookWith: notebookId, entryId: entryID,
    //                                           onSuccess: { [unowned self] in
    //                                               self.success(alert: alert, entryId: entryID) },
    //                                           onError: { [unowned self] message in
    //                                               self.updateErrorBlock(alert: alert, message: message) }) },
    //                                   onError: { [unowned self] message in
    //                                       self.updateErrorBlock(alert: alert, message: message) })
    //                                   },
    //                           onError: { [unowned self] message in
    //                               self.updateErrorBlock(alert: alert, message: message) })
    ////                                    Api.Entry_Labels.saveEntryLabelsWith(entryUid: entryID, labels: [label],
    ////                                            onSuccess: {
    //                                                //},
    ////                                            onError: { [unowned self] message in
    ////                                                self.updateErrorBlock(alert: alert, message: message) })
    ////                    },
    ////                                onError: { [unowned self] message in
    ////                                    self.updateErrorBlock(alert: alert, message: message) })
    //
    //                    },
    //                        onError: { [unowned self] message in
    //                            self.updateErrorBlock(alert: alert, message: message) })
                        
                    },
                    onError: { [unowned self] message in
                        self.updateErrorBlock(alert: alert, message: message)
                })
            }
            // NOTE: Entry without labels
            else {
                guard let userID = Auth.auth().currentUser?.uid else { return }
                for i in self.userTags.tags{
                   self.ref.child("labels").child(userID).child(i.text).child(entryID).setValue(true)
                }
                Api.Entries.saveEntry(forNotebookUid: notebookId, photoUrls: urls, entryUid: entryID, title: title, content: content,
                    onSuccess: { [unowned self] in
                        Api.Entries_Timestamp.setEntryTimestampFor(notebookWith: notebookId, entryId: entryID,
                            onSuccess: { [unowned self, alert] in
                                self.success(alert: alert, entryId: entryID) },
                            onError: { [unowned self] message in
                                self.updateErrorBlock(alert: alert, message: message) }) },
                    onError: { [unowned self] message in
                        self.updateErrorBlock(alert: alert, message: message)
                })
            }
        }
    }
    
    func updateErrorBlock(alert: SCLAlertViewResponder, message: String) {
        alert.close()
        saveButton.isEnabled = true
        SCLAlertView().showError("Oh, Bummer!", subTitle: message)
    }
    
    // MARK:- Updated Dream Entry
    func updateDreamEntry(notebookId: String, entryId: String, title: String, content: String) {
        let alert = SCLAlertView().showWait("Saving...", subTitle: "Please wait...")
        var arrcompressed = [UIImage]()

        for i in self.entryImage{
            
            if let data = try? Data(contentsOf: i)
            {
                let image: UIImage = UIImage(data: data)!
                if let imageData = image.jpegData(compressionQuality: 1.0) {
                    arrcompressed.append(UIImage(data: imageData)!)
                }
                
            }
        }
        
        guard let currentUser = Auth.auth().currentUser else {
            return
        }
        
        let currentUserId = currentUser.uid
        UploadImages.uploadImages(userId: currentUserId, imagesArray: arrcompressed) { (urls) in
            if self.labels.isEmpty && self.updatedLabels == nil {
                // NOTE: The entry simply has no labels - Update Entry with title and content only
                Api.Entries.updateEntryWithUid(uid: entryId, title: title, photoUrls: urls, content: content,
                    onSuccess: { [unowned self, alert] in
                        self.success(alert: alert, entryId: entryId) },
                    onError: { [unowned self] message in
                        self.updateErrorBlock(alert: alert, message: message)
                })
            }
            else if self.labels.isEmpty && self.updatedLabels != nil {
                //NOTE:  User just added labels to the entry
                guard let updatedL = self.updatedLabels else { return }
                Api.Labels.doesLabelExistAlready(labels: updatedL,
                    onExist: { label in
                        Api.Labels.addNewEntryIdForLabel(label: label, entryId: entryId,
                            onSuccess: {
                                Api.Entry_Labels.saveEntryLabelsWith(entryUid: entryId, labels: [label],
                                    onSuccess: {
                                        Api.Entries_Timestamp.setEntryTimestampFor(notebookWith: notebookId, entryId: entryId,
                                            onSuccess: { [unowned self] in
                                                self.success(alert: alert, entryId: entryId) },
                                            onError: { [unowned self] message in
                                                self.updateErrorBlock(alert: alert, message: message) }) },
                                    onError: { [unowned self] message in
                                        self.updateErrorBlock(alert: alert, message: message) }) },
                            onError: { [unowned self] message in
                                self.updateErrorBlock(alert: alert, message: message) }) },
                    onDoesntExist: { label in
                        Api.Labels.addNewLabel(label: label, entryId: entryId,
                            onSuccess: {
                                Api.Entry_Labels.saveEntryLabelsWith(entryUid: entryId, labels: [label],
                                    onSuccess: {
                                        Api.User_Labels.updateLabels(labels: [label],
                                            onSuccess: {
                                                Api.Entries_Timestamp.setEntryTimestampFor(notebookWith: notebookId, entryId: entryId,
                                                    onSuccess: { [unowned self] in
                                                        self.success(alert: alert, entryId: entryId) },
                                                    onError: { [unowned self] message in
                                                        self.updateErrorBlock(alert: alert, message: message) }) },
                                            onError: { [unowned self] message in
                                                self.updateErrorBlock(alert: alert, message: message) }) },
                                    onError: { [unowned self] message in
                                        self.updateErrorBlock(alert: alert, message: message) }) },
                            onError: { [unowned self] message in
                                self.updateErrorBlock(alert: alert, message: message) }) },
                    onError: { [unowned self] message in
                        self.updateErrorBlock(alert: alert, message: message)
                })
            }
            else if !self.labels.isEmpty && self.updatedLabels != nil {
                // NOTE: Entry has existing labels but the user might have changed them (they might be the same, deleted or added more)
                guard let updatedLbls = self.updatedLabels else { return }
                if self.labels.containsSameElement(as: updatedLbls) {
                    // Labels & Updated labels are the same, proceed to just update the title & content only
                    Api.Entries.updateEntryWithUid(uid: entryId, title: title, photoUrls: urls, content: content,
                        onSuccess: { [unowned self] in
                            self.success(alert: alert, entryId: entryId) },
                        onError: { [unowned self] message in
                            self.updateErrorBlock(alert: alert, message: message)
                    })
                }
                else {
                    // Labels are different ... see if they deleted or added labels and if it even have labels (LABELS ARE DEF NOT THE SAME!)
                    if self.labels.count > updatedLbls.count || self.labels.count == updatedLbls.count || updatedLbls.count > self.labels.count {
                        // User Deleted Labels - remove deleted labels from database & update the labels based on updatedLabels elements
                        let possibleLabelsToDelete = Array(Set(self.labels).subtracting(updatedLbls))
                        if possibleLabelsToDelete.count > 0 {
                            for label in possibleLabelsToDelete {
                                Api.Labels.deleteLabelForEntryWith(uid: entryId, label: label,
                                    onSuccess: { [unowned self] in
                                        Api.Entry_Labels.deleteLabelForEntryWith(id: entryId, label: label,
                                            onSuccess: {
                                                self.updateLabelsAndEntryFor(entryId: entryId, title: title, content: content,
                                                    onSuccess: { [unowned self] in
                                                        self.success(alert: alert, entryId: entryId) },
                                                    onError: { [unowned self] message in
                                                        self.updateErrorBlock(alert: alert, message: message) }) },
                                            onError: {[unowned self] message in
                                                self.updateErrorBlock(alert: alert, message: message) }) },
                                    deleteUserLabel: {
                                        Api.User_Labels.deleteLabel(label: label,
                                            onSuccess: { [unowned self] in
                                                self.updateLabelsAndEntryFor(entryId: entryId, title: title, content: content,
                                                    onSuccess: { [unowned self] in
                                                        self.success(alert: alert, entryId: entryId) },
                                                    onError: { [unowned self] message in
                                                        self.updateErrorBlock(alert: alert, message: message) }) },
                                            onError: { [unowned self] message in
                                                self.updateErrorBlock(alert: alert, message: message) }) },
                                    onError: { [unowned self] message in
                                        self.updateErrorBlock(alert: alert, message: message)
                                })
                            }
                        }
                        else {
                            // No Old Labels To delete - proceed to save new updated labels
                            self.updateLabelsAndEntryFor(entryId: entryId, title: title, content: content,
                                onSuccess: { [unowned self] in
                                    self.success(alert: alert, entryId: entryId) },
                                onError: { [unowned self] message in
                                    self.updateErrorBlock(alert: alert, message: message)
                            })
                        }
                    }
                }
            }
        }
       
    }
    
    func updateLabelsAndEntryFor(entryId: String, title: String, content: String, onSuccess: @escaping () -> Void, onError: @escaping (_ message: String) -> Void) {
        _ = SCLAlertView().showWait("Saving...", subTitle: "Please wait...")
        var arrcompressed = [UIImage]()

        for i in self.entryImage{
            
            if let data = try? Data(contentsOf: i)
            {
                let image: UIImage = UIImage(data: data)!
                if let imageData = image.jpegData(compressionQuality: 1.0) {
                    arrcompressed.append(UIImage(data: imageData)!)
                }
                
            }
        }
        
        guard let currentUser = Auth.auth().currentUser else {
            return
        }
        
        let currentUserId = currentUser.uid
        UploadImages.uploadImages(userId: currentUserId, imagesArray: arrcompressed) { (urls) in
            if let updatedL = self.updatedLabels, updatedL.count == 0 {
                // User deleted all labels and there are no new ones, Update only Entry details
                Api.Entries.updateEntryWithUid(uid: entryId, title: title, photoUrls: urls, content: content,
                    onSuccess: {
                        onSuccess() },
                    onError: { message in
                        onError(message)
                        return
                })
            }
            else {
                guard let updatedL = self.updatedLabels else { return }
                // Update /labels & /entry_labels & entry
                Api.Entries.updateEntryWithUid(uid: entryId, title: title, photoUrls: urls, content: content,
                    onSuccess: {
                        Api.Labels.doesLabelExistAlready(labels: updatedL,
                            onExist: { label in
                                Api.Labels.addNewEntryIdForLabel(label: label, entryId: entryId,
                                    onSuccess: {
                                        Api.Entry_Labels.saveEntryLabelsWith(entryUid: entryId, labels: [label],
                                             onSuccess: {
                                                onSuccess() },
                                             onError: { message in
                                                onError(message)
                                                return }) },
                                    onError: { message in
                                        onError(message)
                                        return }) },
                            onDoesntExist: { label in
                               Api.Labels.addNewLabel(label: label, entryId: entryId,
                                    onSuccess: {
                                        Api.Entry_Labels.saveEntryLabelsWith(entryUid: entryId, labels: [label],
                                            onSuccess: {
                                                Api.User_Labels.updateLabels(labels: [label],
                                                    onSuccess: {
                                                        onSuccess() },
                                                    onError: { message in
                                                        onError(message)
                                                        return }) },
                                            onError: { message in
                                                onError(message)
                                                return }) },
                                    onError: { message in
                                        onError(message)
                                        return }) },
                            onError: { message in
                                onError(message)
                                return }) },
                    onError: { message in
                        onError(message)
                })
            }
        }
        
    }
    
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == Segues.NewEntryToSelectNotebookVC {
            let destinationVC = segue.destination as! SelectNotebookVC
            destinationVC.delegate = self
        }
        if segue.identifier == Segues.NewEntryToLabelsVC {
            let navController = segue.destination as! UINavigationController
            var destinationVC = LabelsVC()
            destinationVC = navController.viewControllers[0] as! LabelsVC
            if let updatedL = updatedLabels, updatedL.count >= 0 {
                destinationVC.labels = updatedL
            }
            else if labels.count >= 1 {
                destinationVC.labels = labels
            }
            destinationVC.delegate = self
        }
    }
    
    func clear() {
        updatedLabels?.removeAll()
        labels.removeAll()
    }
    
    deinit {
        print("NewEntryVC deinit")
    }
}


extension NewEntryVC: UITextViewDelegate {
    
    @objc func changeSaveButtonState() {
        guard let updated = updatedLabels
            else {
            // NO UPDATED LABELS
                if !entryTitleTextView.text!.isEmpty, entryTitleTextView.text != "" {
                saveButton.isEnabled = true
                return
            }
            else {
                saveButton.tintColor = UIColor.lightGray
                saveButton.isEnabled = false
            }
            return
        }
        // UPDATED LABELS
        if !labels.containsSameElement(as: updated) || !entryTitleTextView.text!.isEmpty, entryTitleTextView.text != "", let content = entryContentUITextView.text, !content.isEmpty, content != "" {
            saveButton.isEnabled = true
            return
        }
        else {
            saveButton.tintColor = UIColor.lightGray
            saveButton.isEnabled = false
        }
    }
    
    func setTextViewsDelegates() {
        entryTitleTextView.delegate = self
        entryContentUITextView.delegate = self
        setupTitleTextViewPlaceholder()
        setupContentTextViewPlaceholder()
    }
    
    func setupTitleTextViewPlaceholder() {
        titlePlaceholder = UILabel()
//        titlePlaceholder.place = "What strain?"
        titlePlaceholder.textAlignment = .center
        titlePlaceholder.sizeToFit()
        entryTitleTextView.addSubview(titlePlaceholder)
        titlePlaceholder.frame.origin = CGPoint(x: 5, y: (entryTitleTextView.font?.pointSize)! / 2)
        titlePlaceholder.textColor = UIColor.lightGray
        titlePlaceholder.isHidden = !entryTitleTextView.text!.isEmpty
    }

    func setupContentTextViewPlaceholder() {
        contentPlaceholder = UILabel()
        contentPlaceholder.text = "Notes about this strain...(or tag items below)"
        contentPlaceholder.sizeToFit()
        entryContentUITextView.addSubview(contentPlaceholder)
        contentPlaceholder.frame.origin = CGPoint(x: 5, y: (entryContentUITextView.font?.pointSize)! / 2)
        contentPlaceholder.textColor = UIColor.lightGray
        contentPlaceholder.isHidden = !entryContentUITextView.text.isEmpty
        if entry != nil {
            if entry?.content != nil {
                contentPlaceholder.isHidden = true
            }
        }
    }
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        
        titlePlaceholder.isHidden = !entryTitleTextView.text!.isEmpty
        let size = CGSize(width: entryTitleTextView.bounds.width, height: .infinity)
        let estimatedSize = entryTitleTextView.sizeThatFits(size)
        if estimatedSize.height >= 120 {
            titleHeightConstraint.constant = 120
            //entryTitleTextView.isScrollEnabled = true
        }
        else {
           // entryTitleTextView.isScrollEnabled = false
            titleHeightConstraint.constant = estimatedSize.height
        //                let style = NSMutableParagraphStyle()
        //                style.lineSpacing = 20
        //                let attributes = [NSAttributedString.Key.paragraphStyle : style]
        //                entryTitleTextView.attributedText = NSAttributedString(string: textView.text, attributes: attributes)
        }
        saveButton.isEnabled = true
        saveButton.tintColor = .white
        return true
    }
    
    func textViewDidChange(_ textView: UITextView) {
        if textView == entryTitleTextView {
            titlePlaceholder.isHidden = !entryTitleTextView.text!.isEmpty
            let size = CGSize(width: entryTitleTextView.bounds.width, height: .infinity)
            let estimatedSize = entryTitleTextView.sizeThatFits(size)
            if estimatedSize.height >= 120 {
                titleHeightConstraint.constant = 120
                //entryTitleTextView.isScrollEnabled = true
            }
            else {
               // entryTitleTextView.isScrollEnabled = false
                titleHeightConstraint.constant = estimatedSize.height
//                let style = NSMutableParagraphStyle()
//                style.lineSpacing = 20
//                let attributes = [NSAttributedString.Key.paragraphStyle : style]
//                entryTitleTextView.attributedText = NSAttributedString(string: textView.text, attributes: attributes)
            }
        }
        else if textView == entryContentUITextView {
            contentPlaceholder.isHidden = !entryContentUITextView.text.isEmpty
        }
        
        guard let title = entryTitleTextView.text, !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let content = entryContentUITextView.text, !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            else {
                saveButton.tintColor = UIColor.lightGray
                saveButton.isEnabled = false
                return
        }
        saveButton.isEnabled = true
        saveButton.tintColor = .white
    }
}
extension NewEntryVC: SelectNotebookDelegate {
    func setNotebookIdForEntry(notebookId: String) {
        self.notebookId = notebookId
    }
}

extension NewEntryVC: LabelsVCDelegate {
    func transferedLabels(labels: [String]) {
        if entry == nil {
            // New Entry - Initial Label setting
             self.labels = labels
        }
        else {
            // Existing Entry - Update on Labels
            updatedLabels = labels
        }
        changeSaveButtonState()
    }
}
extension NewEntryVC : UINavigationControllerDelegate,UIImagePickerControllerDelegate{
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        
        let img: UIImage?
        self.picker.dismiss(animated: true, completion: nil)
        if  let chosenImage = info[.editedImage] as? UIImage
        {
            img = chosenImage
        }else if let chosenImage = info[.originalImage] as? UIImage{
            img = chosenImage
        } else {
            let alertVC = UIAlertController(
                title: "",
                message: "Invalid media type selected!!!",
                preferredStyle: .alert)
            let okAction = UIAlertAction(title: "OK",style:.default, handler: nil)
            alertVC.addAction(okAction)
            present(alertVC, animated: true, completion: nil)
            return
        }
        if img != nil{
            let imgName = "/\(Date().timeIntervalSince1970).png"
            let documentDirectory = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first
            let localPath = documentDirectory?.appending(imgName)

            
            let data = img!.pngData()! as NSData
            data.write(toFile: localPath!, atomically: true)
            //let imageData = NSData(contentsOfFile: localPath!)!
            let photoURL = URL.init(fileURLWithPath: localPath!)//NSURL(fileURLWithPath: localPath!)
            print(photoURL)
            self.entryImage.append(photoURL)
            self.collVIew.reloadData()
        }
    }
}

extension NewEntryVC : UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout{
   
   func noCamera(){
          let alertVC = UIAlertController(
              title: "No Camera",
              message: "Sorry, this device has no camera",
              preferredStyle: .alert)
          let okAction = UIAlertAction(title: "OK",style:.default, handler: nil)
          alertVC.addAction(okAction)
          present(alertVC, animated: true, completion: nil)
      }

   @objc func pickImage() {
        let alertController = UIAlertController(title: "Upload Profile picture", message: nil, preferredStyle: UIAlertController.Style.actionSheet)
        let pickfromgallery = UIAlertAction(title: "Pick from Gallery", style: .default, handler: { (action) -> Void in
        if UIImagePickerController.isSourceTypeAvailable(UIImagePickerController.SourceType.savedPhotosAlbum){
            self.picker.allowsEditing = false
            self.picker.mediaTypes = [(kUTTypePNG as String), (kUTTypeJPEG as String), (kUTTypeImage as String)]
               self.picker.sourceType = .photoLibrary
               self.picker.modalPresentationStyle = .popover
               if UIDevice.current.userInterfaceIdiom == .pad {
                   let popover = UIPopoverController(contentViewController: self.picker)
                   popover.present(from: self.entryContentUITextView.bounds, in: self.entryContentUITextView, permittedArrowDirections: .any, animated: true)
                   self.popOver = popover
               } else {
                   self.present(self.picker, animated: true, completion: nil)
               }
            self.picker.popoverPresentationController?.barButtonItem = self.saveButton
           }
        })
        let takeaphoto = UIAlertAction(title: "Take a Photo", style: .default, handler: { (action) -> Void in
           if UIImagePickerController.isSourceTypeAvailable(.camera) {
               self.picker.allowsEditing = true
            self.picker.sourceType = UIImagePickerController.SourceType.camera
               self.picker.cameraCaptureMode = .photo
               self.picker.modalPresentationStyle = .fullScreen
               self.present(self.picker, animated: true, completion: nil)
           } else {
               self.noCamera()
           }
        })
        let cancel = UIAlertAction(title: "Cancel", style: .cancel, handler: { (action) -> Void in
        })
        alertController.addAction(pickfromgallery)
        alertController.addAction(takeaphoto)
        alertController.addAction(cancel)
        //alertController.addAction(removepicture)
        if let popoverPresentationController = alertController.popoverPresentationController {
           popoverPresentationController.sourceView = self.view
           popoverPresentationController.sourceRect = self.entryContentUITextView.bounds
        }
        present(alertController, animated: true, completion: nil)
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width:64, height: 64);
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if self.entryImage.count < 5 {
            return self.entryImage.count + 1// + 1 for add image
        }
        return  self.entryImage.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        if self.entryImage.count < 5 {
            if (self.entryImage.count == 0 && indexPath.row == 0) || (indexPath.row == self.entryImage.count) {
                let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "AddImageCell", for: indexPath as IndexPath) as! AddImageCell
                cell.layer.cornerRadius = 10
                cell.layer.borderWidth = 1.0
                cell.layer.borderColor = UIColor.lightGray.cgColor
                cell.btnSelectImg.addTarget(self, action: #selector(pickImage), for: .touchUpInside)
                return cell
            }else{
                let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "EntryImageCell", for: indexPath as IndexPath) as! EntryImageCell
                cell.layer.cornerRadius = 10
                cell.layer.borderWidth = 1.0
                cell.layer.borderColor = UIColor.lightGray.cgColor
                
                cell.btnViewImage.tag = indexPath.row
                cell.btnViewImage.addTarget(self, action: #selector(viewImage(sender:)), for: .touchUpInside)
                cell.imgEntry.isUserInteractionEnabled = true
                let tap = UITapGestureRecognizer(target: self, action: #selector(viewImageimg(sender:)))
                cell.imgEntry.addGestureRecognizer(tap)
                cell.imgEntry.tag = indexPath.row
                cell.btnDelete.tag = indexPath.row
                cell.btnDelete.addTarget(self, action: #selector(deleteImage(sender:)), for: .touchUpInside)
                cell.imgEntry.sd_setImage(with: self.entryImage[indexPath.row], placeholderImage: UIImage())
               return cell
            }
        }else{
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "EntryImageCell", for: indexPath as IndexPath) as! EntryImageCell
            cell.layer.cornerRadius = 10
            cell.layer.borderWidth = 1.0
            cell.layer.borderColor = UIColor.lightGray.cgColor
            
            cell.btnViewImage.tag = indexPath.row
            cell.btnViewImage.addTarget(self, action: #selector(viewImage(sender:)), for: .touchUpInside)
            cell.imgEntry.isUserInteractionEnabled = true
            let tap = UITapGestureRecognizer(target: self, action: #selector(viewImageimg(sender:)))
            cell.imgEntry.addGestureRecognizer(tap)
            cell.imgEntry.tag = indexPath.row
            cell.btnDelete.tag = indexPath.row
            cell.btnDelete.addTarget(self, action: #selector(deleteImage(sender:)), for: .touchUpInside)
            cell.imgEntry.sd_setImage(with: self.entryImage[indexPath.row], placeholderImage: UIImage())
           return cell
        }
        
       
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        
        if (self.entryImage.count == 0 && indexPath.row == 0) || (indexPath.row == self.entryImage.count) {
            
        }else{
            let browser = IDMPhotoBrowser(photoURLs: self.entryImage)
            browser?.delegate = self
            browser?.setInitialPageIndex(UInt(indexPath.row))
            browser?.displayCounterLabel = true
            browser?.displayActionButton = false
            
            self.present(browser!, animated: true)
        }
        
    }
    @objc func viewImageimg(sender: UIGestureRecognizer){
     
        let browser = IDMPhotoBrowser(photoURLs: self.entryImage)
        browser?.delegate = self
        browser?.setInitialPageIndex(UInt(sender.view!.tag))
        browser?.displayCounterLabel = true
        browser?.displayActionButton = false
        
        self.present(browser!, animated: true)
    }
    
    @objc func viewImage(sender: UIButton){
     
        let browser = IDMPhotoBrowser(photoURLs: self.entryImage)
        browser?.delegate = self
        browser?.setInitialPageIndex(UInt(sender.tag))
        browser?.displayCounterLabel = true
        browser?.displayActionButton = false
        
        self.present(browser!, animated: true)
    }
    
    @objc func deleteImage(sender: UIButton) {
        let tag = sender.tag
        self.entryImage.remove(at: tag)
        self.collVIew.reloadData()
    }
}
