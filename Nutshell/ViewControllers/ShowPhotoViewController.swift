/*
* Copyright (c) 2015, Tidepool Project
*
* This program is free software; you can redistribute it and/or modify it under
* the terms of the associated License, which is identical to the BSD 2-Clause
* License as published by the Open Source Initiative at opensource.org.
*
* This program is distributed in the hope that it will be useful, but WITHOUT
* ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
* FOR A PARTICULAR PURPOSE. See the License for more details.
*
* You should have received a copy of the License along with this program; if
* not, you can obtain one from Tidepool Project at tidepool.org.
*/

import UIKit

class ShowPhotoViewController: UIViewController {

    var editAllowed = false
    var photoURLs: [String] = []
    var imageIndex: Int = 0
    var modalPresentation = false
    
    @IBOutlet weak var photoCollectView: EventPhotoCollectView!
    @IBOutlet weak var pageControl: UIPageControl!
    @IBOutlet weak var headerForModalView: NutshellUIView!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        if !modalPresentation {
            // Hide modal header when used as a nav view
            for c in headerForModalView.constraints {
                if c.firstAttribute == NSLayoutAttribute.Height {
                    c.constant = 0.0
                    break
                }
            }
            // We use a custom back button so we can hide the photo to minimizing flashing. This tweaks the arrow positioning to match the iOS back arrow position. TODO: -> actually turned off right now!
            self.navigationItem.leftBarButtonItem?.imageInsets = UIEdgeInsetsMake(0.0, -8.0, -1.0, 0.0)
            if editAllowed {
                navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: UIBarButtonSystemItem.Trash, target: self, action: "deleteButtonHandler:")
            }
        }
    }

    override func viewDidLayoutSubviews() {
        photoCollectView.setNeedsLayout()
        photoCollectView.layoutIfNeeded()
        photoCollectView.photoURLs = photoURLs
        photoCollectView.pageControl = self.pageControl
        photoCollectView.configurePhotoCollection()
    }
    
    private func removeCurrentPhoto() {
        if let curPhotoIndex = photoCollectView.currentCellIndex() {
            let curImageIndex = curPhotoIndex.row
            photoURLs.removeAtIndex(curImageIndex)
            if photoURLs.count == 0 {
                self.performSegueWithIdentifier(EventViewStoryboard.SegueIdentifiers.UnwindSegueFromShowPhoto, sender: self)
            } else {
                photoCollectView.photoURLs = photoURLs
                photoCollectView.configurePhotoCollection()
            }
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        NSLog("Segue from Photo viewer!")
        let currentPhotoIndex = photoCollectView.currentCellIndex()
        if let currentPhotoIndex = currentPhotoIndex {
            imageIndex = currentPhotoIndex.row
        } else {
            imageIndex = 0
        }
    }
    
    @IBAction func backButtonHandler(sender: AnyObject) {
        //photoImageView.hidden = true
        self.performSegueWithIdentifier(EventViewStoryboard.SegueIdentifiers.UnwindSegueFromShowPhoto, sender: self)
    }

    @IBAction func deleteButtonHandler(sender: AnyObject) {
        // removing items from url array sets up the EventAddOrEditVC to delete the photos when edits are saved...
        // TODO: is this dialog really necessary and if so, is wording ok? The photos are not really deleted until you return to the edit scene and tap save. 
        if photoURLs.isEmpty {
            return
        }
        let alert = UIAlertController(title: NSLocalizedString("discardPhotoAlertTitle", comment:"Are you sure?"), message: NSLocalizedString("discardPhotoAlertMessage", comment:"If you delete this photo, your photo will be lost."), preferredStyle: .Alert)
        alert.addAction(UIAlertAction(title: NSLocalizedString("discardAlertCancel", comment:"Cancel"), style: .Cancel, handler: { Void in
            return
        }))
        alert.addAction(UIAlertAction(title: NSLocalizedString("discardAlertOkay", comment:"Discard"), style: .Default, handler: { Void in
            self.removeCurrentPhoto()
        }))
        self.presentViewController(alert, animated: true, completion: nil)
       
    }

}

