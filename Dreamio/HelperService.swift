//
//  HelperService.swift
//  InstagramClone
//
//  Created by The Zero2Launch Team on 1/26/17.
//  Copyright © 2017 The Zero2Launch Team. All rights reserved.
//

import Foundation
import FirebaseStorage
import FirebaseDatabase
import ProgressHUD
import FirebaseAuth

class UploadImages: NSObject{

    static func  saveImages(isPrivate:Bool, imagesArray : [UIImage],ratio: CGFloat,caption: String, onSuccess: @escaping () -> Void) {

        guard let currentUser = Auth.auth().currentUser else {
            return
        }
              
        let currentUserId = currentUser.uid

        uploadImages(userId: currentUserId,imagesArray : imagesArray){ (uploadedImageUrlsArray) in
            print("uploadedImageUrlsArray: \(uploadedImageUrlsArray)")
           // HelperService.sendDataToDatabase(isPrivate: isPrivate, photoUrls: uploadedImageUrlsArray, ratio: ratio, caption: caption, onSuccess: onSuccess)
        }
    }

static func uploadImages(userId: String, imagesArray : [UIImage], completionHandler: @escaping ([String]) -> ()){
    let storage = Storage.storage()

    var uploadedImageUrlsArray = [String]()
    var uploadCount = 0
    let imagesCount = imagesArray.count

    for image in imagesArray{

        let imageName = NSUUID().uuidString // Unique string to reference image

        //Create storage reference for image
        let storageRef = storage.reference().child("\(userId)").child("\(imageName).jpg")
 
        guard let uplodaData = image.pngData() else{
            return
        }

        // Upload image to firebase
        let uploadTask = storageRef.putData(uplodaData, metadata: nil, completion: { (metadata, error) in
            if error != nil{
                print(error as Any)
                return
            }
            
            storageRef.downloadURL { (url, error) in
                if let downloadURL = url {
                    print(downloadURL)
                    uploadedImageUrlsArray.append(downloadURL.absoluteString)
                    
                    uploadCount += 1
                    print("Number of images successfully uploaded: \(uploadCount)")
                    if uploadCount == imagesCount{
                        NSLog("All Images are uploaded successfully, uploadedImageUrlsArray: \(uploadedImageUrlsArray)")
                        completionHandler(uploadedImageUrlsArray)
                    }
                } else {
                  // Uh-oh, an error occurred!
                  return
                }
            }
        })


        observeUploadTaskFailureCases(uploadTask : uploadTask)
    }
}


//Func to observe error cases while uploading image files, Ref: https://firebase.google.com/docs/storage/ios/upload-files


    static func observeUploadTaskFailureCases(uploadTask : StorageUploadTask){
        uploadTask.observe(.failure) { snapshot in
            if let error = snapshot.error as NSError? {
            switch (StorageErrorCode(rawValue: error.code)!) {
            case .objectNotFound:
              NSLog("File doesn't exist")
              break
            case .unauthorized:
              NSLog("User doesn't have permission to access file")
              break
            case .cancelled:
              NSLog("User canceled the upload")
              break

            case .unknown:
              NSLog("Unknown error occurred, inspect the server response")
              break
            default:
              NSLog("A separate error occurred, This is a good place to retry the upload.")
              break
            }
          }
        }
    }

}


class HelperService {
}
