//
//  StatusMenuController.swift
//  GoldenPassport
//
//  Created by StanZhai on 2017/2/25.
//  Copyright © 2017年 StanZhai. All rights reserved.
//

import Cocoa
import Swifter

class StatusMenuController: NSObject {
    var addVerifyKeyWindow: AddVerifyKeyWindow!
    var httpPortConfigWindow: HTTPPortConfigWindow!

    @IBOutlet weak var statusMenu: NSMenu!
    @IBOutlet weak var addMenuItem: NSMenuItem!
    @IBOutlet weak var deleteMenuItem: NSMenuItem!
    @IBOutlet weak var editMenuItem: NSMenuItem!
    @IBOutlet weak var importMenuItem: NSMenuItem!
    @IBOutlet weak var exportMenuItem: NSMenuItem!
    @IBOutlet weak var httpUrlMenuItem: NSMenuItem!
    @IBOutlet weak var httpServerSwitch: NSMenuItem!
    @IBOutlet weak var enableAutoStart: NSMenuItem!
    
    var statusItem: NSStatusItem!
    var timerMenuItem: NSMenuItem!
    var authCodeMenuItems: [NSMenuItem] = []

    var statusIcon: NSImage!
    var copyIcon: NSImage!
    var editIcon: NSImage!
    var removeIcon: NSImage!

    var markDeleteVerifiedKey: Bool = false
    var markEditVerifiedKey: Bool = false
    var needRefreshCodeMenus: Bool = true
    let authCodeMenuItemTagStartIndex = 100
    var http: HttpServer!

    override func awakeFromNib() {
        addVerifyKeyWindow = AddVerifyKeyWindow()
        httpPortConfigWindow = HTTPPortConfigWindow()

        loadIcons()
        initStatusMenuItems()
        initStatusItem()

        let notificationCenter = NotificationCenter.default
        notificationCenter.addObserver(self,
                selector: #selector(verifyCodeAdded),
                name: NSNotification.Name(rawValue: "VerifyKeyAdded"),
                object: nil)
        notificationCenter.addObserver(self,
                selector: #selector(httpServerPortChanged),
                name: NSNotification.Name(rawValue: "HTTPServerPortChanged"),
                object: nil)

        checkAutoStartHttpServer()
    }

    private func loadIcons() {
        statusIcon = NSImage(named: "statusIcon")
        statusIcon.size = NSMakeSize(20, 20)
        statusIcon.isTemplate = true

        let iconSize = NSMakeSize(14, 14)
        copyIcon = NSImage(named: "copyIcon")
        copyIcon.size = iconSize
        copyIcon.isTemplate = true
        
        editIcon = NSImage(named: "editIcon")
        editIcon.size = iconSize
        editIcon.isTemplate = true

        removeIcon = NSImage(named: "removeIcon")
        removeIcon.size = iconSize
        removeIcon.isTemplate = true
    }

    private func initStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.image = statusIcon
        statusItem.target = self

        openMenu(nil)
    }

    private func initStatusMenuItems() {
        statusMenu.insertItem(NSMenuItem.separator(), at: 0)
        timerMenuItem = NSMenuItem()
        statusMenu.insertItem(timerMenuItem, at: 0)
        enableAutoStart.state = NSControl.StateValue(rawValue: DataManager.shared.getHttpServerAutoStart() ? 1 : 0)
    }

    @objc func openMenu(_ sender: AnyObject?) {
        updateMenu()
        updateHttpURLMenuItem()
        let runLoop = RunLoop.current
        let timer = Timer(timeInterval: TimeInterval(1), target: self, selector: #selector(updateMenu), userInfo: nil, repeats: true)
        runLoop.add(timer, forMode: RunLoop.Mode.eventTracking)
        statusItem.menu = statusMenu
        updateHttpSwitchMenuItem()
    }

    @objc func updateMenu() {
        let now = Date()
        let calendar = Calendar(identifier: Calendar.Identifier.gregorian)
        let dateComponents = calendar.dateComponents([.second], from: now)
        let second = 30 - dateComponents.second! % 30

        timerMenuItem.title = "\(EXPIRE_TIME_STR)\(second)s"

        let authCodes = DataManager.shared.allAuthCode()

        if needRefreshCodeMenus {
            authCodeMenuItems.removeAll()

            for menuItem in statusMenu.items {
                if menuItem.tag >= authCodeMenuItemTagStartIndex {
                    statusMenu.removeItem(menuItem)
                }
            }

            var idx = 0
            for codeInfo in authCodes {
                let authCodeMenuItem = NSMenuItem()
                authCodeMenuItem.title = "\(codeInfo.key): \(codeInfo.value)"
                authCodeMenuItem.target = self
                authCodeMenuItem.action = #selector(authCodeMenuItemClicked)
                authCodeMenuItem.tag = authCodeMenuItemTagStartIndex + idx
                authCodeMenuItem.toolTip = markDeleteVerifiedKey ? DELETE_VERIFY_KEY_STR : COPY_AUTH_CODE_STR
                authCodeMenuItem.image = markDeleteVerifiedKey ? removeIcon : copyIcon
                authCodeMenuItem.keyEquivalent = "\(idx)"
                authCodeMenuItem.keyEquivalentModifierMask = [.command, .shift]
                authCodeMenuItems.append(authCodeMenuItem)
                statusMenu.insertItem(authCodeMenuItem, at: idx)
                idx = idx + 1
            }
            needRefreshCodeMenus = false
        } else {
            var idx = 0
            for codeInfo in authCodes {
                authCodeMenuItems[idx].title = "\(codeInfo.key): \(codeInfo.value)"
                idx = idx + 1
            }
        }
    }

    @objc func authCodeMenuItemClicked(_ sender: NSMenuItem) {
        let authCodes = DataManager.shared.allAuthCode()
        let dataIdx = sender.tag - authCodeMenuItemTagStartIndex
        if dataIdx < authCodes.count {
            var idx = 0
            for codeInfo in authCodes {
                if idx == dataIdx {
                    if markDeleteVerifiedKey {
                        DataManager.shared.removeOTPAuthURL(tag: codeInfo.key)
                        needRefreshCodeMenus = true
                        updateMenu()
                    } else if markEditVerifiedKey {
                        addVerifyKeyWindow.showWindow(nil)
                        addVerifyKeyWindow.window?.makeKeyAndOrderFront(nil)
                        addVerifyKeyWindow.editFor(key: codeInfo.key)
                        NSApp.activate(ignoringOtherApps: true)
                    } else {
                        let pasteboard = NSPasteboard.general
                        pasteboard.clearContents()
                        pasteboard.setString(codeInfo.value, forType: .string)
                    }
                    break
                }
                idx = idx + 1
            }
        }
    }

    @objc func verifyCodeAdded() {
        needRefreshCodeMenus = true
    }

    @objc func httpServerPortChanged() {
        updateHttpURLMenuItem()
        if (http != nil && http.state == HttpServerIO.HttpServerIOState.running) {
            restartHttpServer()
        }
    }
    
    private func updateHttpSwitchMenuItem() {
        if (http == nil || http.state != HttpServerIO.HttpServerIOState.running) {
            httpServerSwitch.title = "开启HTTP服务"
        } else {
            httpServerSwitch.title = "停止HTTP服务"
        }
    }

    private func updateHttpURLMenuItem() {
        let serverPort = DataManager.shared.getHttpServerPort()
        let url = "浏览器访问 http://localhost:\(serverPort)"
        httpUrlMenuItem.title = url
        if (http == nil) {
            httpUrlMenuItem.isHidden = true
        } else {
            if (http.state == HttpServerIO.HttpServerIOState.running) {
                httpUrlMenuItem.isHidden = false
            } else {
                httpUrlMenuItem.isHidden = true
            }
        }
    }

    private func checkAutoStartHttpServer() {
        if (DataManager.shared.getHttpServerAutoStart()) {
            restartHttpServer()
        }
        updateHttpSwitchMenuItem()
    }

    private func stopHttpServer() {
        if (http != nil && http.state == HttpServerIO.HttpServerIOState.running) {
            http.stop()
        }
    }

    private func startHttpServer() {
        let serverPort = DataManager.shared.getHttpServerPort()
        if http == nil {
            http = httpServer()
        }
        do {
            try http.start(UInt16(serverPort)!, forceIPv4: true)
        } catch {
            let alert = NSAlert()
            alert.messageText = "HTTP服务启动失败:\n\(error)"
            alert.runModal()
        }
    }

    private func restartHttpServer() {
        stopHttpServer()
        startHttpServer()
    }
    
    private func updateAuthCodeMenu() {
        for authCodeMenuItem in authCodeMenuItems {
            if markDeleteVerifiedKey {
                authCodeMenuItem.toolTip = DELETE_VERIFY_KEY_STR
                authCodeMenuItem.image = removeIcon
            } else if markEditVerifiedKey {
                authCodeMenuItem.toolTip = EDIT_VERIFY_KEY_STR
                authCodeMenuItem.image = editIcon
            } else {
                authCodeMenuItem.toolTip = COPY_AUTH_CODE_STR
                authCodeMenuItem.image = copyIcon
            }
        }
    }

    @IBAction func addVerifyClicked(_ sender: NSMenuItem) {
        addVerifyKeyWindow.showWindow(nil)
        addVerifyKeyWindow.window?.makeKeyAndOrderFront(nil)
        addVerifyKeyWindow.clearTextField()
        NSApp.activate(ignoringOtherApps: true)
    }

    @IBAction func editClicked(_ sender: NSMenuItem) {
        markEditVerifiedKey = !markEditVerifiedKey

        editMenuItem.title = markEditVerifiedKey ? DONE_EDIT_STR : EDIT_STR

        updateAuthCodeMenu()

        if markEditVerifiedKey {
            let alert: NSAlert = NSAlert()
            alert.messageText = "已进入编辑模式，请到状态栏菜单中编辑认证信息。\n\n编辑后，请执行`\(DONE_EDIT_STR)`退出删除模式"
            alert.addButton(withTitle: "确定")
            alert.alertStyle = NSAlert.Style.informational
            alert.runModal()
        }
    }

    @IBAction func deleteClicked(_ sender: NSMenuItem) {
        markDeleteVerifiedKey = !markDeleteVerifiedKey

        deleteMenuItem.title = markDeleteVerifiedKey ? DONE_REMOVE_STR : REMOVE_STR

        updateAuthCodeMenu()

        if markDeleteVerifiedKey {
            let alert: NSAlert = NSAlert()
            alert.messageText = "已进入删除模式，请到状态栏菜单中删除认证信息。\n\n删除后，请执行`\(DONE_REMOVE_STR)`退出删除模式"
            alert.addButton(withTitle: "确定")
            alert.alertStyle = NSAlert.Style.informational
            alert.runModal()
        }
    }

    @IBAction func importClicked(_ sender: NSMenuItem) {
        let openPanel = NSOpenPanel()
        openPanel.allowedFileTypes = ["secrets"]
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseDirectories = false
        openPanel.canCreateDirectories = false
        openPanel.canChooseFiles = true

        let i = openPanel.runModal()
        if i == NSApplication.ModalResponse.cancel {
            return
        }
        let count = DataManager.shared.importData(dist: openPanel.url!)
        needRefreshCodeMenus = true
        let alert = NSAlert()
        alert.messageText = "成功导入\(count)条记录！"
        alert.runModal()
    }
    
    @IBAction func exportClicked(_ sender: NSMenuItem) {
        let savePanel = NSSavePanel()
        savePanel.title = "导出认证信息"
        savePanel.nameFieldStringValue = "GoldenPassport.secrets"
        let i = savePanel.runModal()
        if i == NSApplication.ModalResponse.cancel {
            return
        }
        DataManager.shared.exportData(dist: savePanel.url!)
    }
    
    @IBAction func configHttpPortClicked(_ sender: NSMenuItem) {
        httpPortConfigWindow.showWindow(nil)
        httpPortConfigWindow.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @IBAction func switchClicked(_ sender: Any) {
        if (http == nil || http.state != HttpServerIO.HttpServerIOState.running) {
            startHttpServer()
        } else {
            stopHttpServer()
        }
    }
    
    @IBAction func urlClicked(_ sender: NSMenuItem) {
        let serverPort = DataManager.shared.getHttpServerPort()
        if let url = URL(string: "http://localhost:\(serverPort)") {
            NSWorkspace.shared.open(url)
        }
    }
    
    @IBAction func enableAutoStartClicked(_ sender: Any) {
        if enableAutoStart.state.rawValue == 1 {
            enableAutoStart.state = NSControl.StateValue(rawValue: 0)
            DataManager.shared.saveHttpServerAutoStart(auto: false)
        } else {
            enableAutoStart.state = NSControl.StateValue(rawValue: 1)
            DataManager.shared.saveHttpServerAutoStart(auto: true)
        }
    }
    
    @IBAction func aboutClicked(sender: NSMenuItem) {
        if let url = URL(string: "https://github.com/stanzhai/GoldenPassport") {
            NSWorkspace.shared.open(url)
        }
    }

    @IBAction func quitClicked(sender: NSMenuItem) {
        let notificationCenter = NotificationCenter.default
        notificationCenter.removeObserver(self)
        NSApplication.shared.terminate(self)
    }
}
