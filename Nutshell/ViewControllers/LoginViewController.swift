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
import Alamofire
import SwiftyJSON
import CocoaLumberjack
import MessageUI
import HealthKit
// FIXME: comparison operators with optionals were removed from the Swift Standard Libary.
// Consider refactoring the code to use the non-optional operators.
fileprivate func < <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
  switch (lhs, rhs) {
  case let (l?, r?):
    return l < r
  case (nil, _?):
    return true
  default:
    return false
  }
}

// FIXME: comparison operators with optionals were removed from the Swift Standard Libary.
// Consider refactoring the code to use the non-optional operators.
fileprivate func > <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
  switch (lhs, rhs) {
  case let (l?, r?):
    return l > r
  default:
    return rhs < lhs
  }
}


/// Presents the UI to capture email and password for login and calls APIConnector to login. Show errors to the user. Backdoor UI for development setting of the service.
class LoginViewController: BaseUIViewController, MFMailComposeViewControllerDelegate {

    @IBOutlet weak var logInScene: UIView!
    @IBOutlet weak var logInEntryContainer: UIView!

    @IBOutlet weak var inputContainerView: UIView!
    @IBOutlet weak var offlineMessageContainerView: UIView!
    
    @IBOutlet weak var emailTextField: NutshellUITextField!
    @IBOutlet weak var passwordTextField: NutshellUITextField!
    @IBOutlet weak var loginButton: UIButton!
    @IBOutlet weak var loginIndicator: UIActivityIndicatorView!
    @IBOutlet weak var errorFeedbackLabel: NutshellUILabel!
    @IBOutlet weak var forgotPasswordLabel: NutshellUILabel!
    
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    deinit {
        let nc = NotificationCenter.default
        nc.removeObserver(self, name: nil, object: nil)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        let notificationCenter = NotificationCenter.default

        notificationCenter.addObserver(self, selector: #selector(LoginViewController.textFieldDidChange), name: NSNotification.Name.UITextFieldTextDidChange, object: nil)
        updateButtonStates()
        
        // forgot password text needs an underline...
        if let forgotText = forgotPasswordLabel.text {
            let forgotStr = NSAttributedString(string: forgotText, attributes:[NSFontAttributeName: forgotPasswordLabel.font, NSUnderlineStyleAttributeName: NSUnderlineStyle.styleSingle.rawValue])
            forgotPasswordLabel.attributedText = forgotStr
        }
        // TODO: hide for now until implemented!
        forgotPasswordLabel.isHidden = true
        
        notificationCenter.addObserver(self, selector: #selector(LoginViewController.keyboardWillShow(_:)), name: NSNotification.Name.UIKeyboardWillShow, object: nil)
        notificationCenter.addObserver(self, selector: #selector(LoginViewController.keyboardWillHide(_:)), name: NSNotification.Name.UIKeyboardWillHide, object: nil)

        NotificationCenter.default.addObserver(self, selector: #selector(LoginViewController.reachabilityChanged(_:)), name: ReachabilityChangedNotification, object: nil)
        configureForReachability()
        
        // Tap all four corners to bring up server selection action sheet
        let width: CGFloat = 100
        let height: CGFloat = width
        corners.append(CGRect(x: 0, y: 0, width: width, height: height))
        corners.append(CGRect(x: self.view.frame.width - width, y: 0, width: width, height: height))
        corners.append(CGRect(x: 0, y: self.view.frame.height - height, width: width, height: height))
        corners.append(CGRect(x: self.view.frame.width - width, y: self.view.frame.height - height, width: width, height: height))
        for _ in 0 ..< corners.count {
            cornersBool.append(false)
        }
    }
    
    func reachabilityChanged(_ note: Notification) {
        if let appDelegate = UIApplication.shared.delegate as? AppDelegate {
            // try token refresh if we are now connected...
            // TODO: change message to "attempting token refresh"?
            let api = APIConnector.connector()
            if api.isConnectedToNetwork() && api.sessionToken != nil {
                NSLog("Login: attempting to refresh token...")
                api.refreshToken() { succeeded -> (Void) in
                    if succeeded {
                        appDelegate.setupUIForLoginSuccess()
                    } else {
                        NSLog("Refresh token failed, need to log in normally")
                        api.logout() {
                            self.configureForReachability()
                        }
                    }
                }
                return
            }
        }
        configureForReachability()
    }

    fileprivate func configureForReachability() {
        let connected = APIConnector.connector().isConnectedToNetwork()
        inputContainerView.isHidden = !connected
        offlineMessageContainerView.isHidden = connected
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    //
    // MARK: - Button and text field handlers
    //

    @IBAction func tapOutsideFieldHandler(_ sender: AnyObject) {
        passwordTextField.resignFirstResponder()
        emailTextField.resignFirstResponder()
    }
    
    @IBAction func passwordEnterHandler(_ sender: AnyObject) {
        passwordTextField.resignFirstResponder()
        if (loginButton.isEnabled) {
            login_button_tapped(self)
        }
    }

    @IBAction func emailEnterHandler(_ sender: AnyObject) {
        passwordTextField.becomeFirstResponder()
    }
    
    @IBAction func login_button_tapped(_ sender: AnyObject) {
        updateButtonStates()
        loginIndicator.startAnimating()
        
        APIConnector.connector().login(emailTextField.text!,
            password: passwordTextField.text!) { (result:Alamofire.Result<User>) -> (Void) in
                //NSLog("Login result: \(result)")
                self.processLoginResult(result)
        }
    }
    
    fileprivate func processLoginResult(_ result: Alamofire.Result<User>) {
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        self.loginIndicator.stopAnimating()
        if (result.isSuccess) {
            if let user=result.value {
                NSLog("Login success: \(user)")
                APIConnector.connector().fetchProfile() { (result:Alamofire.Result<JSON>) -> (Void) in
                        NSLog("Profile fetch result: \(result)")
                    if (result.isSuccess) {
                        if let json = result.value {
                            NutDataController.controller().processProfileFetch(json)
                        }
                    }
                }
                appDelegate.setupUIForLoginSuccess()
            } else {
                // This should not happen- we should not succeed without a user!
                NSLog("Fatal error: No user returned!")
            }
        } else {
            NSLog("login failed! Error: " + result.error.debugDescription)
            var errorText = NSLocalizedString("loginErrUserOrPassword", comment: "Wrong email or password!")
            if let error = result.error {
                NSLog("NSError: \(error)")
                if (error as NSError).code == -1009 {
                    errorText = NSLocalizedString("loginErrOffline", comment: "The Internet connection appears to be offline!")
                }
                // TODO: handle network offline!
            }
            self.errorFeedbackLabel.text = errorText
            self.errorFeedbackLabel.isHidden = false
            self.passwordTextField.text = ""
        }
    }
    
    
    
    func textFieldDidChange() {
        updateButtonStates()
    }

    fileprivate func updateButtonStates() {
        errorFeedbackLabel.isHidden = true
        // login button
        if (emailTextField.text != "" && passwordTextField.text != "") {
            loginButton.isEnabled = true
            loginButton.setTitleColor(UIColor.white, for:UIControlState())
        } else {
            loginButton.isEnabled = false
            loginButton.setTitleColor(UIColor.lightGray, for:UIControlState())
        }
    }

    //
    // MARK: - View handling for keyboard
    //

    fileprivate var viewAdjustAnimationTime: Float = 0.25
    fileprivate func adjustLogInView(_ centerOffset: CGFloat) {
        
        for c in logInScene.constraints {
            if c.firstAttribute == NSLayoutAttribute.centerY {
                c.constant = -centerOffset
                break
            }
        }
        UIView.animate(withDuration: TimeInterval(viewAdjustAnimationTime), animations: {
            self.logInScene.layoutIfNeeded()
        }) 
    }
   
    // UIKeyboardWillShowNotification
    func keyboardWillShow(_ notification: Notification) {
        // make space for the keyboard if needed
        let keyboardFrame = (notification.userInfo![UIKeyboardFrameEndUserInfoKey] as! NSValue).cgRectValue
        viewAdjustAnimationTime = notification.userInfo![UIKeyboardAnimationDurationUserInfoKey] as! Float
        let loginViewDistanceToBottom = logInScene.frame.height - logInEntryContainer.frame.origin.y - logInEntryContainer.frame.size.height
        let additionalKeyboardRoom = keyboardFrame.height - loginViewDistanceToBottom
        if (additionalKeyboardRoom > 0) {
            self.adjustLogInView(additionalKeyboardRoom)
        }
    }
    
    // UIKeyboardWillHideNotification
    func keyboardWillHide(_ notification: Notification) {
        // reposition login view if needed
        self.adjustLogInView(0.0)
    }

    // MARK: - Debug Config
    
    fileprivate var corners: [CGRect] = []
    fileprivate var cornersBool: [Bool] = []
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let touch = touches.first {
            
            let touchLocation = touch.location(in: self.view)
            
            var i = 0
            for corner in corners {
                let viewFrame = self.view.convert(corner, from: self.view)
                
                if viewFrame.contains(touchLocation) {
                    cornersBool[i] = true
                    self.checkCorners()
                    return
                }
                
                i += 1
            }
        }
    }

    func checkCorners() {
        for cornerBool in cornersBool {
            if (!cornerBool) {
                return
            }
        }
        
        showServerActionSheet()
    }
    
    func showServerActionSheet() {
        for i in 0 ..< corners.count {
            cornersBool[i] = false
        }
        let api = APIConnector.connector()
        let actionSheet = UIAlertController(title: "Settings" + " (" + api.currentService! + ")", message: "", preferredStyle: .actionSheet)
        for server in api.kServers {
            actionSheet.addAction(UIAlertAction(title: server.0, style: .default, handler: { Void in
                let serverName = server.0
                api.switchToServer(serverName)
            }))
        }
        actionSheet.addAction(UIAlertAction(title: "Count HealthKit Blood Glucose Samples", style: .default, handler: {
            Void in
            self.handleCountBloodGlucoseSamples()
        }))
        actionSheet.addAction(UIAlertAction(title: "Find date range for blood glucose samples", style: .default, handler: {
            Void in
            self.handleFindDateRangeBloodGlucoseSamples()
        }))
        actionSheet.addAction(UIAlertAction(title: "Email export of HealthKit blood glucose data", style: .default, handler: {
            Void in
            self.handleEmailExportOfBloodGlucoseData()
        }))
        if defaultDebugLevel == DDLogLevel.off {
            actionSheet.addAction(UIAlertAction(title: "Enable logging", style: .default, handler: { Void in
                defaultDebugLevel = DDLogLevel.verbose
                UserDefaults.standard.set(true, forKey: "LoggingEnabled");
                UserDefaults.standard.synchronize()
                
            }))
        } else {
            actionSheet.addAction(UIAlertAction(title: "Disable logging", style: .default, handler: { Void in
                defaultDebugLevel = DDLogLevel.off
                UserDefaults.standard.set(false, forKey: "LoggingEnabled");
                UserDefaults.standard.synchronize()
                self.clearLogFiles()
            }))
        }
        actionSheet.addAction(UIAlertAction(title: "Email logs", style: .default, handler: { Void in
            self.handleEmailLogs()
        }))
        
        if let popoverController = actionSheet.popoverPresentationController {
            popoverController.sourceView = self.view
            popoverController.sourceRect = logInEntryContainer.bounds
        }
        self.present(actionSheet, animated: true, completion: nil)
    }

    func clearLogFiles() {
        // Clear log files
        let logFileInfos = fileLogger.logFileManager.unsortedLogFileInfos
        for logFileInfo in logFileInfos! {
            if let logFilePath = logFileInfo.filePath {
                do {
                    try FileManager.default.removeItem(atPath: logFilePath)
                    logFileInfo.reset()
                    DDLogInfo("Removed log file: \(logFilePath)")
                } catch let error as NSError {
                    DDLogError("Failed to remove log file at path: \(logFilePath) error: \(error), \(error.userInfo)")
                }
            }
        }
    }
    
    //
    // MARK: - Debug action handlers - HealthKit Debug UI
    //

    func handleCountBloodGlucoseSamples() {
        HealthKitManager.sharedInstance.countBloodGlucoseSamples {
            (error: NSError?, totalSamplesCount: Int, totalDexcomSamplesCount: Int) in
            
            var alert: UIAlertController?
            let title = "HealthKit Blood Glucose Sample Count"
            var message = ""
            if error == nil {
                message = "There are \(totalSamplesCount) blood glucose samples and \(totalDexcomSamplesCount) Dexcom samples in HealthKit"
            } else if HealthKitManager.sharedInstance.authorizationRequestedForBloodGlucoseSamples() {
                message = "Error counting samples: \(error)"
            } else {
                message = "Unable to count sample. Maybe you haven't connected to Health yet. Please login and connect to Health and try again."
            }
            DDLogInfo(message)
            alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
            alert!.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
            DispatchQueue.main.async(execute: {
                self.present(alert!, animated: true, completion: nil)
            })
        }
    }
    
    func handleFindDateRangeBloodGlucoseSamples() {
        let sampleType = HKObjectType.quantityType(forIdentifier: HKQuantityTypeIdentifier.bloodGlucose)!
        HealthKitManager.sharedInstance.findSampleDateRange(sampleType: sampleType) {
            (error: NSError?, startDate: Date?, endDate: Date?) in
            
            var alert: UIAlertController?
            let title = "Date range for blood glucose samples"
            var message = ""
            if error == nil && startDate != nil && endDate != nil {
                let days = startDate!.differenceInDays(endDate!) + 1
                message = "Start date: \(startDate), end date: \(endDate). Total days: \(days)"
            } else {
                message = "Unable to find date range for blood glucose samples, maybe you haven't connected to Health yet, please login and connect to Health and try again. Or maybe there are no samples in HealthKit."
            }
            DDLogInfo(message)
            alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
            alert!.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
            DispatchQueue.main.async(execute: {
                self.present(alert!, animated: true, completion: nil)
            })
        }
    }
    
    func handleEmailLogs() {
        DDLog.flushLog()
        
        let logFilePaths = fileLogger.logFileManager.sortedLogFilePaths as [String]
        var logFileDataArray = [Data]()
        for logFilePath in logFilePaths {
            let fileURL = NSURL(fileURLWithPath: logFilePath)
            if let logFileData = try? NSData(contentsOf: fileURL as URL, options: NSData.ReadingOptions.mappedIfSafe) {
                // Insert at front to reverse the order, so that oldest logs appear first.
                logFileDataArray.insert(logFileData as Data, at: 0)
            }
        }
        
        if MFMailComposeViewController.canSendMail() {
            let appName = Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as! String
            let composeVC = MFMailComposeViewController()
            composeVC.mailComposeDelegate = self
            composeVC.setSubject("Logs for \(appName)")
            composeVC.setMessageBody("", isHTML: false)
            
            let attachmentData = NSMutableData()
            for logFileData in logFileDataArray {
                attachmentData.append(logFileData)
            }
            composeVC.addAttachmentData(attachmentData as Data, mimeType: "text/plain", fileName: "\(appName).txt")
            self.present(composeVC, animated: true, completion: nil)
        }
    }
    
    func handleEmailExportOfBloodGlucoseData() {
        let sampleType = HKObjectType.quantityType(forIdentifier: HKQuantityTypeIdentifier.bloodGlucose)!
        let sampleQuery = HKSampleQuery(sampleType: sampleType, predicate: nil, limit: HKObjectQueryNoLimit, sortDescriptors: nil) {
            (query, samples, error) -> Void in
            
            if error == nil && samples?.count > 0 {
                // Write header row
                let rows = NSMutableString()
                rows.append("sequence,sourceBundleId,UUID,date,value,units\n")
                
                // Write rows
                let dateFormatter = DateFormatter()
                var sequence = 0
                for sample in samples! {
                    sequence += 1
                    let sourceBundleId = sample.sourceRevision.source.bundleIdentifier
                    let UUIDString = sample.uuid.uuidString
                    let date = dateFormatter.isoStringFromDate(sample.startDate, zone: TimeZone(secondsFromGMT: 0), dateFormat: iso8601dateZuluTime)
                    
                    if let quantitySample = sample as? HKQuantitySample {
                        let units = "mg/dL"
                        let unit = HKUnit(from: units)
                        let value = quantitySample.quantity.doubleValue(for: unit)
                        rows.append("\(sequence),\(sourceBundleId),\(UUIDString),\(date),\(value),\(units)\n")
                    } else {
                        rows.append("\(sequence),\(sourceBundleId),\(UUIDString)\n")
                    }
                }
                
                // Send mail
                if MFMailComposeViewController.canSendMail() {
                    let composeVC = MFMailComposeViewController()
                    composeVC.mailComposeDelegate = self
                    composeVC.setSubject("HealthKit blood glucose samples")
                    composeVC.setMessageBody("", isHTML: false)
                    
                    if let attachmentData = rows.data(using: String.Encoding.utf8.rawValue, allowLossyConversion: false) {
                        composeVC.addAttachmentData(attachmentData, mimeType: "text/csv", fileName: "HealthKit Samples.csv")
                    }
                    self.present(composeVC, animated: true, completion: nil)
                }
                
            } else {
                var alert: UIAlertController?
                let title = "Error"
                let message = "Unable to export HealthKit blood glucose data. Maybe you haven't connected to Health yet. Please login and connect to Health and try again. Or maybe there is no blood glucose data in Health."
                DDLogInfo(message)
                alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
                alert!.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                DispatchQueue.main.async(execute: {
                    self.present(alert!, animated: true, completion: nil)
                })
            }
        }
        
        HKHealthStore().execute(sampleQuery)
    }
    
    func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
        controller.dismiss(animated: true, completion: nil)
    }
}
