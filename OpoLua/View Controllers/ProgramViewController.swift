// Copyright (c) 2021 Jason Morley, Tom Sutcliffe
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

import UIKit

class ProgramViewController: UIViewController {

    struct TextDetails {
        let size: Graphics.Size
        let ascent: Int
    }

    var program: Program

    var drawableHandle = (1...).makeIterator()
    var drawables: [Int: Drawable] = [:]
    var infoDrawableHandle: Int?
    var infoWindowDismissTimer: Timer?

    let menu: ConcurrentBox<[UIMenuElement]> = ConcurrentBox()
    let menuCompletion: ConcurrentBox<(Int) -> Void> = ConcurrentBox()

    let menuQueue = DispatchQueue(label: "ProgramViewController.menuQueue")

    lazy var canvasView: CanvasView = {
        let canvas = newCanvas(size: program.screenSize.cgSize(), color: true)
        let canvasView = CanvasView(canvas: canvas)
        canvasView.translatesAutoresizingMaskIntoConstraints = false
        canvasView.layer.borderWidth = 1.0
        canvasView.layer.borderColor = UIColor.black.cgColor
        canvasView.clipsToBounds = true
        drawables[1] = canvasView // 1 is always the main window
        return canvasView
    }()

    lazy var consoleBarButtonItem: UIBarButtonItem = {
        return UIBarButtonItem(image: UIImage(systemName: "terminal"),
                               style: .plain,
                               target: self,
                               action: #selector(consoleTapped(sender:)))
    }()

    init(program: Program) {
        self.program = program
        super.init(nibName: nil, bundle: nil)
        program.delegate = self
        navigationItem.largeTitleDisplayMode = .never
        view.backgroundColor = .systemBackground
        navigationItem.title = program.name
        view.clipsToBounds = true
        view.addSubview(canvasView)
        NSLayoutConstraint.activate([

            canvasView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            canvasView.centerYAnchor.constraint(equalTo: view.centerYAnchor),

        ])

        self.toolbarItems = [consoleBarButtonItem]
        
        let items = UIDeferredMenuElement.uncached { [weak self] completion in
            guard let self = self else {
                return
            }
            self.menuQueue.async {
                self.program.sendMenu()
                let disabled = UIAction(title: "None", attributes: .disabled) { _ in }
                let items = self.menu.tryTake(until: Date().addingTimeInterval(0.1)) ?? [disabled]
                DispatchQueue.main.async {
                    completion(items)
                }
            }
        }
        let menu = UIMenu(title: "", image: nil, identifier: nil, options: [], children: [items])
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: nil,
                                                            image: UIImage(systemName: "ellipsis.circle"),
                                                            primaryAction: nil,
                                                            menu: menu)


        // Unfortunately there doesn't seem to be a great way to detect when the user dismisses the menu.
        // This implementation uses SPI to do just that by watching the notification center for presentation dismiss
        // notifications and ignores notifications for anything that isn't a menu.
        NotificationCenter.default.addObserver(forName: NSNotification.Name.UIPresentationControllerDismissalTransitionDidEndNotification,
                                               object: nil,
                                               queue: .main) { notification in
            guard let UIContextMenuActionsOnlyViewController = NSClassFromString("_UIContextMenuActionsOnlyViewController"),
                  let object = notification.object,
                  type(of: object) == UIContextMenuActionsOnlyViewController
            else {
                return
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.menuCompletion.tryTake()?(0)
            }
        }

        canvasView.delegate = program
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.isToolbarHidden = false
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        program.start()
    }

    @objc func consoleTapped(sender: UIBarButtonItem) {
        showConsole()
    }

    func showConsole() {
        let viewController = ConsoleViewController(program: program)
        viewController.delegate = self
        let navigationController = UINavigationController(rootViewController: viewController)
        present(navigationController, animated: true)
    }

    private func newCanvas(size: CGSize, color: Bool) -> Canvas {
        dispatchPrecondition(condition: .onQueue(.main))
        let canvas = Canvas(id: drawableHandle.next()!, size: size, color: color)
        return canvas
    }

    func createBitmap(size: Graphics.Size) -> Canvas {
        dispatchPrecondition(condition: .onQueue(.main))
        let canvas = newCanvas(size: size.cgSize(), color: false)
        drawables[canvas.id] = canvas
        return canvas
    }
    /**
     N.B. Windows are hidden by default.
     */
    func createWindow(rect: Graphics.Rect, shadowSize: Int) -> Canvas {
        dispatchPrecondition(condition: .onQueue(.main))
        let canvas = self.newCanvas(size: rect.size.cgSize(), color: true)
        let newView = CanvasView(canvas: canvas, shadowSize: shadowSize)
        newView.isHidden = true
        newView.frame = rect.cgRect()
        newView.delegate = self.program
        self.canvasView.addSubview(newView)
        self.drawables[canvas.id] = newView
        bringInfoWindowToFront()
        return canvas
    }

    func setVisiblity(handle: Int, visible: Bool) {
        dispatchPrecondition(condition: .onQueue(.main))
        guard let view = self.drawables[handle] as? CanvasView else {
            print("No CanvasView for showWindow operation")
            return
        }
        view.isHidden = !visible
    }

    /**
     N.B. In OPL terms position=1 means the front, whereas subviews[1] is at the back.
     */
    func order(displayId: Int, position: Int) {
        dispatchPrecondition(condition: .onQueue(.main))
        guard let view = self.drawables[displayId] as? CanvasView else {
            return
        }
        let views = self.canvasView.subviews
        let uipos = views.count - position
        if views.count == 0 || uipos < 0 {
            self.canvasView.sendSubviewToBack(view)
        } else {
            self.canvasView.insertSubview(view, aboveSubview: views[uipos])
        }
        bringInfoWindowToFront()
    }


    func close(displayId: Int) {
        guard let view = self.drawables[displayId] as? CanvasView else {
            return
        }
        view.removeFromSuperview()
        self.drawables[displayId] = nil
    }

    func bringInfoWindowToFront() {
        guard let infoDrawableHandle = infoDrawableHandle,
              let infoView = self.drawables[infoDrawableHandle] as? CanvasView
        else {
            return
        }
        self.canvasView.bringSubviewToFront(infoView)
    }

    @objc func closeInfoWindow() {
        guard let infoDrawableHandle = infoDrawableHandle else {
            return
        }
        close(displayId: infoDrawableHandle)
        self.infoDrawableHandle = nil
        infoWindowDismissTimer?.invalidate()
    }

    func infoPrint(text: String, corner: Graphics.Corner) {
        closeInfoWindow()
        guard !text.isEmpty else {
            return
        }
        let fontInfo = Graphics.FontInfo(face: .arial, size: 15, flags: .init()) // TODO: Empty flags?
        let details = Self.textSize(string: text, fontInfo: fontInfo)
        let canvas = self.createWindow(rect: .init(origin: .zero, size: details.size), shadowSize: 0)
        canvas.draw(.init(displayId: canvas.id,
                          type: .fill(details.size),
                          mode: .set,
                          origin: .zero,
                          color: .black,
                          bgcolor: .black))
        canvas.draw(.init(displayId: canvas.id,
                          type: .text(text, fontInfo),
                          mode: .set,
                          origin: .init(x: 0, y: details.size.height),
                          color: .white,
                          bgcolor: .white))
        self.setVisiblity(handle: canvas.id, visible: true)
        infoDrawableHandle = canvas.id

        infoWindowDismissTimer = Timer.scheduledTimer(timeInterval: 2.0,
                                                      target: self,
                                                      selector: #selector(closeInfoWindow),
                                                      userInfo: nil,
                                                      repeats: false)
    }

    func performGraphicsOperation(_ operation: Graphics.Operation) -> Graphics.Result {
        dispatchPrecondition(condition: .onQueue(.main))
        switch (operation) {

        case .createBitmap(let size):
            let canvas = createBitmap(size: size)
            return .handle(canvas.id)

        case .createWindow(let rect, let shadowSize):
            let canvas = createWindow(rect: rect, shadowSize: shadowSize)
            return .handle(canvas.id)

        case .close(let displayId):
            close(displayId: displayId)
            return .nothing

        case .order(let displayId, let position):
            order(displayId: displayId, position: position)
            return .nothing

        case .show(let displayId, let flag):
            setVisiblity(handle: displayId, visible: flag)
            return .nothing

        case .textSize(let string, let fontInfo):
            let details = Self.textSize(string: string, fontInfo: fontInfo)
            return .sizeAndAscent(details.size, details.ascent)

        case .busy(let text, let corner, _):
            // TODO: Implement BUSY
            infoPrint(text: text, corner: corner)
            return .nothing

        case .giprint(let text, let corner):
            infoPrint(text: text, corner: corner)
            return .nothing

        case .setwin(let displayId, let pos, let size):
            if let view = self.drawables[displayId] as? CanvasView {
                if let size = size {
                    view.resize(to: size.cgSize())
                }
                view.frame = CGRect(origin: pos.cgPoint(), size: view.frame.size)
            } else {
                print("No CanvasView for setwin operation")
            }
            return .nothing

        }
    }

    static func textSize(string: String, fontInfo: Graphics.FontInfo) -> TextDetails {
        let font = fontInfo.toUiFont()
        let attribStr = NSAttributedString(string: string, attributes: [.font: font])
        let sz = attribStr.size()
        // This is not really the right definition for ascent but it seems to work for where epoc expects
        // the text to be, so...
        let ascent = Int(ceil(sz.height) + font.descender)
        return TextDetails(size: Graphics.Size(width: Int(ceil(sz.width)), height: Int(ceil(sz.height))),
                           ascent: ascent)
    }

    override var canBecomeFirstResponder: Bool {
        return true
    }

    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        for press in presses {
            if let key = press.key {
                let timestamp = Int(press.timestamp)
                let modifiers = key.oplModifiers()

                let (keydownCode, keypressCode) = key.toOplCodes()

                // The could be no legitimate keydownCode if we're inputting say
                // a tilde which is not on a key that the Psion 5 keyboard has
                if let code = keydownCode {
                    program.sendEvent(.keydownevent(.init(timestamp: timestamp, keycode: code, modifiers: modifiers)))
                } else {
                    print("No keydown code for \(key)")
                }

                if let code = keypressCode, code.toCharcode() != nil {
                    let event = Async.KeyPressEvent(timestamp: timestamp, keycode: code, modifiers: modifiers, isRepeat: false)
                    if event.modifiedKeycode() != nil {
                        program.sendEvent(.keypressevent(event))
                    }
                } else {
                    print("No keypress code for \(key)")
                }
            }
        }
    }

    override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        for press in presses {
            if let key = press.key {
                let (oplKey, _) = key.toOplCodes()
                if let oplKey = oplKey {
                    let timestamp = Int(press.timestamp)
                    let modifiers = key.oplModifiers()
                    program.sendEvent(.keyupevent(.init(timestamp: timestamp, keycode: oplKey, modifiers: modifiers)))
                }
            }
        }
    }

}

extension ProgramViewController: ConsoleViewControllerDelegate {

    func consoleViewControllerDidDismiss(_ consoleViewController: ConsoleViewController) {
        consoleViewController.dismiss(animated: true)
    }

}

extension ProgramViewController: ProgramDelegate {

    func program(_ program: Program, didFinishWithResult result: OpoInterpreter.Result) {
        showConsole()
    }

    func program(_ program: Program, didEncounterError error: Error) {
        present(error: error)
    }
    
    func readLine(escapeShouldErrorEmptyInput: Bool) -> String? {
        // TODO: Implement INPUT
        return "123"
    }
    
    func alert(lines: [String], buttons: [String]) -> Int {
        let semaphore = DispatchSemaphore(value: 0)
        var result = 1
        DispatchQueue.main.async {
            let message = lines.joined(separator: "\n")
            let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
            if buttons.count > 0 {
                for (index, button) in buttons.enumerated() {
                    alert.addAction(.init(title: button, style: .default) { action in
                        result = index + 1
                        semaphore.signal()
                    })
                }
            } else {
                alert.addAction(.init(title: "Continue", style: .default) { action in
                    semaphore.signal()
                })
            }
            self.present(alert, animated: true, completion: nil)
        }
        semaphore.wait()
        return result
    }

    func dialog(_ dialog: Dialog) -> Dialog.Result {
        let semaphore = DispatchSemaphore(value: 0)
        var result = Dialog.Result(result: 0, values: [])
        DispatchQueue.main.async {
            result = Dialog.Result(result: 0, values: [])
            let viewController = DialogViewController(dialog: dialog) { key, values in
                result = Dialog.Result(result: key, values: values)
                semaphore.signal()
            }
            let navigationController = UINavigationController(rootViewController: viewController)
            self.present(navigationController, animated: true)
        }
        semaphore.wait()
        return result
    }

    func menu(_ menu: Menu.Bar) -> Menu.Result {
        let semaphore = DispatchSemaphore(value: 0)
        var result: Menu.Result = .none
        self.menuCompletion.put { keycode in
            result = Menu.Result(selected: keycode, highlighted: keycode)
            semaphore.signal()
        }
        self.menu.put(menu.menuElements { keycode in
            self.menuCompletion.tryTake()?(keycode)
        })
        semaphore.wait()
        return result
    }

    func draw(operations: [Graphics.DrawCommand]) {
        DispatchQueue.main.sync {
            for op in operations {
                guard let drawable = self.drawables[op.displayId] else {
                    print("No drawable for displayid \(op.displayId)!")
                    continue
                }

                switch (op.type) {
                case .copy(let src, let mask):
                    // These need some massaging to shoehorn in the src Drawable pointer
                    guard let srcCanvas = self.drawables[src.displayId] else {
                        print("Copy operation with unknown source \(src.displayId)!")
                        continue
                    }
                    let newSrc = Graphics.CopySource(displayId: src.displayId, rect: src.rect, extra: srcCanvas.getImage())
                    let newMaskSrc: Graphics.CopySource?
                    if let mask = mask, let maskCanvas = self.drawables[mask.displayId] {
                        newMaskSrc = Graphics.CopySource(displayId: mask.displayId, rect: mask.rect, extra: maskCanvas)
                    } else {
                        newMaskSrc = nil
                    }
                    let newOp = Graphics.DrawCommand(displayId: op.displayId, type: .copy(newSrc, newMaskSrc),
                                                     mode: op.mode, origin: op.origin,
                                                     color: op.color, bgcolor: op.bgcolor)
                    drawable.draw(newOp)
                case .pattern(let info):
                    let extra: AnyObject?
                    if info.displayId == -1 {
                        guard let img = UIImage(named: "DitherPattern")?.cgImage else {
                            print("Failed to load DitherPattern!")
                            return
                        }
                        extra = img
                    } else {
                        guard let srcCanvas = self.drawables[info.displayId] else {
                            print("Pattern operation with unknown source \(info.displayId)!")
                            continue
                        }
                        extra = srcCanvas.getImage()
                    }
                    let newInfo = Graphics.CopySource(displayId: info.displayId, rect: info.rect, extra: extra)
                    let newOp = Graphics.DrawCommand(displayId: op.displayId, type: .pattern(newInfo),
                                                     mode: op.mode, origin: op.origin,
                                                     color: op.color, bgcolor: op.bgcolor)
                    drawable.draw(newOp)
                default:
                    drawable.draw(op)
                }

            }
        }
    }

    func graphicsop(_ operation: Graphics.Operation) -> Graphics.Result {
        var result: Graphics.Result!
        DispatchQueue.main.sync {
            result = performGraphicsOperation(operation)
        }
        return result
    }

}

extension Menu.Bar {

    func menuElements(completion: @escaping (Int) -> Void) -> [UIMenuElement] {
        return menus.map { menu in
            return UIMenu(title: menu.title, children: menu.menuElements(completion: completion))
        }

    }

}

extension Menu {

    func menuElements(completion: @escaping (Int) -> Void) -> [UIMenuElement] {
        return items.map { item in
            if let submenu = item.submenu {
                return UIMenu(title: submenu.title, children: submenu.menuElements(completion: completion))
            } else {
                return UIAction(title: item.text, subtitle: item.shortcut) { action in
                    completion(item.keycode)
                }
            }
        }
    }

}
