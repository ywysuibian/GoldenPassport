//
//  AddVerifyKeyController.swift
//  GoldenPassport
//
//  Created by StanZhai on 2017/2/25.
//  Copyright © 2017年 StanZhai. All rights reserved.
//

import Cocoa
import CoreImage

class AddVerifyKeyWindow: NSWindowController, NSWindowDelegate {
    @IBOutlet weak var otpTextField: NSTextField!
    @IBOutlet weak var tagTextField: NSTextField!
    @IBOutlet weak var okBtn: NSButton!
    
    private var editForKey = ""
    
    override var windowNibName : String! {
        return "AddVerifyKeyWindow"
    }
    
    override func windowDidLoad() {
        super.windowDidLoad()
        self.window?.isOpaque = false
        self.window?.titlebarAppearsTransparent = true
        //self.window?.styleMask = [window!.styleMask, .fullSizeContentView]
        let color = NSColor(calibratedRed: 0.0, green: 0.0, blue: 0.0, alpha: 0.75)
        self.window?.backgroundColor = color
        self.window?.isMovableByWindowBackground = true
        self.window?.center()
    }
    
    func clearTextField() {
        otpTextField.stringValue = ""
        tagTextField.stringValue = ""
        editForKey = ""
        okBtn.title = "添加"
    }
    
    func editFor(key: String) {
        editForKey = key
        okBtn.title = "修改"
        let url = DataManager.shared.getOTPAuthURL(tag: key)
        if url != "" {
            tagTextField.stringValue = key
            otpTextField.stringValue = url
        } else {
            let alert: NSAlert = NSAlert()
            alert.addButton(withTitle: "确定")
            alert.alertStyle = NSAlert.Style.warning
            alert.messageText = "找不到[" + key + "]对应的OTP URL！"
            alert.alertStyle = NSAlert.Style.warning
            alert.runModal()
        }
    }
    
    @IBAction func selectPicClicked(_ sender: NSButton) {
        let openPanel = NSOpenPanel()
        openPanel.allowedFileTypes = NSImage.imageTypes
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseDirectories = false
        openPanel.canCreateDirectories = false
        openPanel.canChooseFiles = true
        
        let i = openPanel.runModal()
        if i == NSApplication.ModalResponse.cancel {
            return
        }
        
        let ciImage = CIImage(contentsOf: openPanel.url!)
        let detector = CIDetector(ofType: CIDetectorTypeQRCode, context: nil, options: [CIDetectorAccuracy: CIDetectorAccuracyLow])
        let results = detector?.features(in: ciImage!)
        if (results?.count)! > 0 {
            let qrFeature = results?.last as! CIQRCodeFeature
            let data = qrFeature.messageString
            otpTextField.stringValue = data!
            
            let otpInfo = OTPAuthURLParser(data!)!
            if (otpInfo.user != nil) {
                tagTextField.stringValue = otpInfo.user! + "@" + otpInfo.host
            } else {
                tagTextField.stringValue = otpInfo.host
            }
            
        }
    }

    @IBAction func okBtnClicked(_ sender: NSButton) {
        let url = otpTextField.stringValue
        let tag = tagTextField.stringValue
        
        let alert: NSAlert = NSAlert()
        alert.addButton(withTitle: "确定")
        alert.alertStyle = NSAlert.Style.informational
        
        var isValid = false
        if let otpInfo = OTPAuthURLParser(url) {
            isValid = OTPAuthURL.base32Decode(otpInfo.secret) != nil
        }
        
        if isValid {
            var notityStr = "VerifyKeyAdded"
            var actionStr = "添加"
            if editForKey != "" {
                DataManager.shared.removeOTPAuthURL(tag: editForKey)
                notityStr = "VerifyKeyEdited"
                actionStr = "编辑"
            }
            DataManager.shared.addOTPAuthURL(tag: tag, url: url)
            
            let notificationCenter = NotificationCenter.default
            notificationCenter.post(name: NSNotification.Name(rawValue: notityStr), object: nil)
            
            self.window?.close()
            
            alert.messageText = actionStr + "成功，请到状态栏菜单查看。"
        } else {
            alert.messageText = "无法解析密钥，请检查OTPAuth URL。"
            alert.alertStyle = NSAlert.Style.warning
        }
        
        alert.runModal()
    }
    
    @IBAction func cancelBtnClicked(_ sender: NSButton) {
        self.window?.close()
    }
}
