//
//  AuthApi.swift
//  Dreamio
//
//  Created by Bold Lion on 18.02.19.
//  Copyright © 2019 Bold Lion. All rights reserved.
//

import Foundation
import FirebaseAuth
import FirebaseDatabase

class AuthApi {
    
    //***********************************//
    //**** MARK: - LOGIN USER
    //***********************************//
    let REF_USERS = Database.database().reference().child(DatabaseLocation.users)
    func loginWith(username: String, password: String, onSuccess: @escaping () -> Void, onError: @escaping (_ errorMessage: String?) -> Void) {
        REF_USERS.queryOrdered(byChild: "username").queryEqual(toValue: username.lowercased()).observeSingleEvent(of: .value, with:  { snapshot in
            if snapshot.exists() {
                let email = ((snapshot.children.allObjects[0] as! DataSnapshot).value as! NSDictionary).value(forKey: "email") as! String
                Api.Auth.loginWith(email: email, password: password, onSuccess: {
                    onSuccess()
                }, onError: { error in
                    //SCLAlertView().showError("Error", subTitle: error!)
                    onError(error?.description)
                })
            }
            else {
                onError("Username not exitst")
            }
        })
    }
    
    func loginWith(email: String, password: String, onSuccess: @escaping () -> Void, onError: @escaping (_ errorMessage: String?) -> Void) {
        Auth.auth().signIn(withEmail: email, password: password, completion: { user, error in
            if error != nil  {
                onError(error!.localizedDescription)
                return
            }
            onSuccess()
        })
    }

    //***********************************//
    //**** MARK: - REGISTER NEW USER
    //***********************************//
    func registerWith(username: String, email: String, password: String, onSuccess: @escaping () -> Void, onError: @escaping (_ errorMessage: String) -> Void)  {
        // Does the username already exist?
         Api.Users.doesUsernameExistInDatabase(username: username, onSuccess: { [unowned self] in
            Auth.auth().createUser(withEmail: email, password: password, completion: { [unowned self] _, error in
                if error != nil {
                    onError(error!.localizedDescription)
                    return
                }
                if let uid = Auth.auth().currentUser?.uid {
                    self.setUserInformation(username: username, email: email, uid: uid, onSuccess: {
                        Api.Notebooks.createFirstNotebook(onSuccess: onSuccess, onError: onError)
                    }, onError: onError)
                }
            })
         }, onError: { message in
                guard let errMessage = message else { return }
                onError(errMessage)
                return
         })
    }
    
    //***********************************//
    //**** MARK: - SET USERS DATABASE
    //***********************************//
    func setUserInformation(username: String, email: String, uid: String, onSuccess: @escaping () -> Void, onError: @escaping (_ message: String) -> Void) {
        let userDictData =  [ "username" : username.lowercased(),
                              "email"    : email ]
        Api.Users.REF_USERS.child(uid).setValue(userDictData, withCompletionBlock: { error, _ in
            if error == nil {
                onSuccess()
            }
            else {
                onError(error!.localizedDescription)
                return
            }
        })
    }
    
    //***********************************//
    //**** MARK: - RETRIEVE PASSWORD
    //***********************************//
    func resetPassword(withEmail: String, onSuccess: @escaping () -> Void,  onError: @escaping (_ errorMessage: String) -> Void) {
        Auth.auth().sendPasswordReset(withEmail: withEmail) { error in
            if error != nil {
                onError(error!.localizedDescription)
                return
            }
            else {
                onSuccess()
            }
        }
    }
    
    //***********************************//
    //**** MARK: - Update User Username
    //***********************************//
    func updateUserUsername(username: String, onSuccess:  @escaping () -> Void, onError: @escaping (_ errorMessage: String?) -> Void) {
        Api.Users.doesUsernameExistInDatabase(username: username, onSuccess: {
            Api.Users.REF_CURRENT_USER?.updateChildValues(["username": username.lowercased()], withCompletionBlock: { error, ref in
                if error != nil {
                    onError(error!.localizedDescription)
                    return
                }
                else {
                    onSuccess()
                }
            })
        }, onError: onError)
    }
    
    //***********************************//
    //**** MARK: - Update User Email
    //***********************************//
    func updateUserEmail(email: String, onSuccess:  @escaping () -> Void, onError: @escaping (_ errorMessage: String?) -> Void) {
        Api.Users.CURRENT_USER?.updateEmail(to: email, completion: {  error in
            if error != nil {
                onError(error!.localizedDescription)
                return
            }
            else {
                Api.Users.REF_CURRENT_USER?.updateChildValues(["email": email], withCompletionBlock: { error, ref in
                    if error != nil {
                        onError(error!.localizedDescription)
                        return
                    }
                    else {
                        onSuccess()
                    }
                })
            }
        })
    }
    
    //***********************************//
    //**** MARK: - Update User Password
    //***********************************//
    func updateUserPassword(email: String, currentPassword: String, newPassword: String, onError: @escaping (_ error: String) -> Void, onSuccess: @escaping () -> Void ) {
        let credential = EmailAuthProvider.credential(withEmail: email, password: currentPassword)
        Auth.auth().currentUser?.reauthenticate(with: credential, completion: { result, error in
            if error == nil {
                Api.Users.CURRENT_USER?.updatePassword(to: newPassword) { errror in
                    if error != nil {
                        onError(error!.localizedDescription)
                        return
                    }
                    else {
                        onSuccess()
                    }
                }
            }
            else {
                onError(error!.localizedDescription)
                return
            }
        })
    }
    
    
    //***********************************//
    //**** MARK: - Re-Autheticate User
    //***********************************//
    func reauthenticateUser(email: String, currentPassword: String, onError: @escaping (_ error: String) -> Void, onSuccess: @escaping () -> Void ) {
        let credential = EmailAuthProvider.credential(withEmail: email, password: currentPassword)
        Auth.auth().currentUser?.reauthenticate(with: credential, completion: { result, error in
            if error == nil {
                onSuccess()
            }
            else {
                onError(error!.localizedDescription)
                return
            }
        })
    }
    
    
//    //***********************************//
//    //**** MARK: - Log out
//    //***********************************//
//    func logout(onSuccess: @escaping () -> Void, onError: @escaping (_ errorMessage: String) -> Void) {
//        do {
//            try Auth.auth().signOut()
//            onSuccess()
//        }
//        catch let logoutError {
//            onError(logoutError.localizedDescription)
//            return
//        }
//    }
    
    deinit {
        print("AuthApi class has been deinitialised")
    }
}
