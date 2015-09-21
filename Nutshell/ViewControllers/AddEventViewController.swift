//
//  AddEventViewController.swift
//  Nutshell
//
//  Created by Larry Kenyon on 9/18/15.
//  Copyright © 2015 Tidepool. All rights reserved.
//

import UIKit
import CoreData

class AddEventViewController: UIViewController {

    @IBOutlet weak var photoUIImageView: UIImageView!
    
    @IBOutlet weak var titleEventButton: NutshellUIButton!
    @IBOutlet weak var missingPhotoView: UIView!
    
    @IBOutlet weak var titleTextField: NutshellUITextField!
    @IBOutlet weak var notesTextField: NutshellUITextField!
    
    @IBOutlet weak var eventDate: NutshellUILabel!

    @IBOutlet weak var saveButton: UIButton!
    @IBOutlet weak var addSuccessView: NutshellUIView!
    @IBOutlet weak var addSuccessImageView: UIImageView!

    private var eventTime = NSDate()
    
    override func viewDidLoad() {
        super.viewDidLoad()

        saveButton.hidden = true
        let df = NSDateFormatter()
        df.dateFormat = uniformDateFormat
        eventDate.text = df.stringFromDate(eventTime)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBAction func titleEventButtonHandler(sender: NutshellUIButton) {
        titleTextField.becomeFirstResponder()
        titleEventButton.hidden = true
    }
    
    func textFieldDidBeginEditing(textField: UITextField) {
        notesTextField.becomeFirstResponder()
        notesTextField.selectAll(nil)
    }
    
    @IBAction func titleTextDidEnd(sender: AnyObject) {
        updateSaveButtonState()
    }
    
    @IBAction func notesEditingDidEnd(sender: AnyObject) {
        updateSaveButtonState()
        notesTextField.resignFirstResponder()
    }
    
    private func updateSaveButtonState() {
        if titleTextField.text?.characters.count == 0 {
            titleEventButton.hidden = false
            saveButton.hidden = true
        } else {
            saveButton.hidden = false
        }
    }
    
    @IBAction func notesEditingDidBegin(sender: AnyObject) {
    }
    
    private func addDemoData() {
        
        let demoMeals = [
            ["Three tacos", "with 15 chips & salsa", "2015-07-29 04:55:27 +0000", "home"],
            ["Three tacos", "after ballet", "2015-07-29 04:55:27 +0000", "238 Garrett St"],
            ["Three tacos", "Apple Juice before", "2015-07-10 14:25:21 +0000", "Golden Gate Park"],
            ["Three tacos", "and horchata", "2015-07-09 14:25:21 +0000", "Golden Gate Park"],
            ["Workout", "running in park", "2015-07-08 14:25:21 +0000", ""],
            ["", "Only notes for this one", "2015-07-07 14:25:21 +0000", ""],
            ["CPK 5 cheese margarita", "", "2015-07-06 14:25:21 +0000", ""],
            ["Bagel & cream cheese fruit", "", "2015-07-05 14:25:21 +0000", ""],
            ["Birthday Party", "", "2015-07-04 14:25:21 +0000", ""],
            ["Soccer Practice", "", "2015-07-03 14:25:21 +0000", ""],
        ]
        
        func addMeal(me: Meal, event: [String], df: NSDateFormatter) {
            me.title = event[0]
            me.notes = event[1]
            if (event[2] == "") {
                me.time = NSDate()
            } else {
                me.time = df.dateFromISOString(event[2])
            }
            me.location = event[3]
            me.photo = ""
            me.type = "meal"
            me.id = NSUUID().UUIDString // required!
            let now = NSDate()
            me.createdTime = now
            me.modifiedTime = now
        }
        
        let df = NSDateFormatter()
        let ad = UIApplication.sharedApplication().delegate as! AppDelegate
        let moc = ad.managedObjectContext
        if let entityDescription = NSEntityDescription.entityForName("Meal", inManagedObjectContext: moc) {
            for event in demoMeals {
                let me = NSManagedObject(entity: entityDescription, insertIntoManagedObjectContext: nil) as! Meal
                addMeal(me, event: event, df: df)
                moc.insertObject(me)
            }
        }
    }

    @IBAction func saveButtonHandler(sender: AnyObject) {
        
        let ad = UIApplication.sharedApplication().delegate as! AppDelegate
        let moc = ad.managedObjectContext
        if let entityDescription = NSEntityDescription.entityForName("Meal", inManagedObjectContext: moc) {
            
            // This is a good place to splice in demo and test data. For now, entering "demo" as the title will result in us adding a set of demo events to the model, and "delete" will delete all food events.
            if titleTextField.text == "demo" {
                addDemoData()
            } else if titleTextField.text == "delete" {
                DatabaseUtils.deleteAllMealEvents(moc)
            } else {
                let me = NSManagedObject(entity: entityDescription, insertIntoManagedObjectContext: nil) as! Meal
                
                me.location = ""
                me.title = titleTextField.text
                me.notes = notesTextField.text
                me.photo = ""
                me.type = "meal"
                me.time = eventTime // required!
                me.id = NSUUID().UUIDString // required!
                let now = NSDate()
                me.createdTime = now
                me.modifiedTime = now
                moc.insertObject(me)
            }
            
            // Save the database
            do {
                try moc.save()
                print("addEvent: Database saved!")
                showSuccessView()
            } catch let error as NSError {
                // TO DO: error message!
                print("Failed to save MOC: \(error)")
            }
        }
    }
    
    private func showSuccessView() {
        let animations: [UIImage]? = [UIImage(named: "addAnimation-01")!,
            UIImage(named: "addAnimation-02")!,
            UIImage(named: "addAnimation-03")!,
            UIImage(named: "addAnimation-04")!,
            UIImage(named: "addAnimation-05")!,
            UIImage(named: "addAnimation-06")!]
        addSuccessImageView.animationImages = animations
        addSuccessImageView.animationDuration = 1.0
        addSuccessImageView.animationRepeatCount = 1
        addSuccessImageView.startAnimating()
        addSuccessView.hidden = false
        
        NutUtils.delay(1.0) {
            self.navigationController?.popViewControllerAnimated(true)
        }
    }
    
    private func exitAddEventVC(object: AnyObject) {
        
    }
    
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}