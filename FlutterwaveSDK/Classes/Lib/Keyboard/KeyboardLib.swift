//
//  KeyboardLib.swift
//  FlutterwaveSDK
//
//  Created by Rotimi Joshua on 23/09/2020.
//  Copyright © 2020 Flutterwave. All rights reserved.
//




import Foundation
import CoreGraphics
import UIKit
import QuartzCore

// MARK: IQToolbar tags

/**
Codeless drop-in universal library allows to prevent issues of keyboard sliding up and cover UITextField/UITextView. Neither need to write any code nor any setup required and much more. A generic version of KeyboardManagement. https://developer.apple.com/library/ios/documentation/StringsTextFonts/Conceptual/TextAndWebiPhoneOS/KeyboardManagement/KeyboardManagement.html
*/

@objc public class IQKeyboardManager: NSObject {

    /**
    Returns the default singleton instance.
    */
    @objc public static let shared = IQKeyboardManager()

    /**
     Invalid point value.
     */
    internal static let  kIQCGPointInvalid = CGPoint.init(x: CGFloat.greatestFiniteMagnitude, y: CGFloat.greatestFiniteMagnitude)

    // MARK: UIKeyboard handling

    /**
    Enable/disable managing distance between keyboard and textField. Default is YES(Enabled when class loads in `+(void)load` method).
    */
    @objc public var enable = false {

        didSet {
            //If not enable, enable it.
            if enable, !oldValue {
                //If keyboard is currently showing. Sending a fake notification for keyboardWillHide to retain view's original position.
                if let notification = keyboardShowNotification {
                    keyboardWillShow(notification)
                }
                showLog("Enabled")
            } else if !enable, oldValue {   //If not disable, desable it.
                keyboardWillHide(nil)
                showLog("Disabled")
            }
        }
    }

    /**
    To set keyboard distance from textField. can't be less than zero. Default is 10.0.
    */
    @objc public var keyboardDistanceFromTextField: CGFloat = 10.0

    // MARK: IQToolbar handling

    /**
    Automatic add the IQToolbar functionality. Default is YES.
    */
    @objc public var enableAutoToolbar = true {
        didSet {
            privateIsEnableAutoToolbar() ? addToolbarIfRequired() : removeToolbarIfRequired()

            let enableToolbar = enableAutoToolbar ? "Yes" : "NO"

            showLog("enableAutoToolbar: \(enableToolbar)")
        }
    }

    /**
     /**
     IQAutoToolbarBySubviews:   Creates Toolbar according to subview's hirarchy of Textfield's in view.
     IQAutoToolbarByTag:        Creates Toolbar according to tag property of TextField's.
     IQAutoToolbarByPosition:   Creates Toolbar according to the y,x position of textField in it's superview coordinate.

     Default is IQAutoToolbarBySubviews.
     */
    AutoToolbar managing behaviour. Default is IQAutoToolbarBySubviews.
    */
    @objc public var toolbarManageBehaviour = IQAutoToolbarManageBehaviour.bySubviews

    /**
    If YES, then uses textField's tintColor property for IQToolbar, otherwise tint color is default. Default is NO.
    */
    @objc public var shouldToolbarUsesTextFieldTintColor = false

    /**
    This is used for toolbar.tintColor when textfield.keyboardAppearance is UIKeyboardAppearanceDefault. If shouldToolbarUsesTextFieldTintColor is YES then this property is ignored. Default is nil and uses black color.
    */
    @objc public var toolbarTintColor: UIColor?

    /**
     This is used for toolbar.barTintColor. Default is nil.
     */
    @objc public var toolbarBarTintColor: UIColor?

    /**
     IQPreviousNextDisplayModeDefault:      Show NextPrevious when there are more than 1 textField otherwise hide.
     IQPreviousNextDisplayModeAlwaysHide:   Do not show NextPrevious buttons in any case.
     IQPreviousNextDisplayModeAlwaysShow:   Always show nextPrevious buttons, if there are more than 1 textField then both buttons will be visible but will be shown as disabled.
     */
    @objc public var previousNextDisplayMode = IQPreviousNextDisplayMode.default

    /**
     Toolbar previous/next/done button icon, If nothing is provided then check toolbarDoneBarButtonItemText to draw done button.
     */
    @objc public var toolbarPreviousBarButtonItemImage: UIImage?
    @objc public var toolbarNextBarButtonItemImage: UIImage?
    @objc public var toolbarDoneBarButtonItemImage: UIImage?

    /**
     Toolbar previous/next/done button text, If nothing is provided then system default 'UIBarButtonSystemItemDone' will be used.
     */
    @objc public var toolbarPreviousBarButtonItemText: String?
    @objc public var toolbarPreviousBarButtonItemAccessibilityLabel: String?
    @objc public var toolbarNextBarButtonItemText: String?
    @objc public var toolbarNextBarButtonItemAccessibilityLabel: String?
    @objc public var toolbarDoneBarButtonItemText: String?
    @objc public var toolbarDoneBarButtonItemAccessibilityLabel: String?

    /**
    If YES, then it add the textField's placeholder text on IQToolbar. Default is YES.
    */
    @objc public var shouldShowToolbarPlaceholder = true

    /**
    Placeholder Font. Default is nil.
    */
    @objc public var placeholderFont: UIFont?

    /**
     Placeholder Color. Default is nil. Which means lightGray
     */
    @objc public var placeholderColor: UIColor?

    /**
     Placeholder Button Color when it's treated as button. Default is nil.
     */
    @objc public var placeholderButtonColor: UIColor?

    // MARK: UIKeyboard appearance overriding

    /**
    Override the keyboardAppearance for all textField/textView. Default is NO.
    */
    @objc public var overrideKeyboardAppearance = false

    /**
    If overrideKeyboardAppearance is YES, then all the textField keyboardAppearance is set using this property.
    */
    @objc public var keyboardAppearance = UIKeyboardAppearance.default

    // MARK: UITextField/UITextView Next/Previous/Resign handling

    /**
    Resigns Keyboard on touching outside of UITextField/View. Default is NO.
    */
    @objc public var shouldResignOnTouchOutside = false {

        didSet {
            resignFirstResponderGesture.isEnabled = privateShouldResignOnTouchOutside()

            let shouldResign = shouldResignOnTouchOutside ? "Yes" : "NO"

            showLog("shouldResignOnTouchOutside: \(shouldResign)")
        }
    }

    /** TapGesture to resign keyboard on view's touch. It's a readonly property and exposed only for adding/removing dependencies if your added gesture does have collision with this one */
    @objc lazy public var resignFirstResponderGesture: UITapGestureRecognizer = {

        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(self.tapRecognized(_:)))
        tapGesture.cancelsTouchesInView = false
        tapGesture.delegate = self

        return tapGesture
    }()

    /*******************************************/

    /**
    Resigns currently first responder field.
    */
    @objc @discardableResult public func resignFirstResponder() -> Bool {

        guard let textFieldRetain = textFieldView else {
            return false
        }

        //Resigning first responder
        guard textFieldRetain.resignFirstResponder() else {
            showLog("Refuses to resign first responder: \(textFieldRetain)")
            //  If it refuses then becoming it as first responder again.    (Bug ID: #96)
            //If it refuses to resign then becoming it first responder again for getting notifications callback.
            textFieldRetain.becomeFirstResponder()
            return false
        }
        return true
    }

    // MARK: UISound handling

    /**
    If YES, then it plays inputClick sound on next/previous/done click.
    */
    @objc public var shouldPlayInputClicks = true

    // MARK: UIAnimation handling

    /**
    If YES, then calls 'setNeedsLayout' and 'layoutIfNeeded' on any frame update of to viewController's view.
    */
    @objc public var layoutIfNeededOnUpdate = false

    // MARK: Class Level disabling methods

    /**
     Disable distance handling within the scope of disabled distance handling viewControllers classes. Within this scope, 'enabled' property is ignored. Class should be kind of UIViewController.
     */
    @objc public var disabledDistanceHandlingClasses  = [UIViewController.Type]()

    /**
     Enable distance handling within the scope of enabled distance handling viewControllers classes. Within this scope, 'enabled' property is ignored. Class should be kind of UIViewController. If same Class is added in disabledDistanceHandlingClasses list, then enabledDistanceHandlingClasses will be ignored.
     */
    @objc public var enabledDistanceHandlingClasses  = [UIViewController.Type]()

    /**
     Disable automatic toolbar creation within the scope of disabled toolbar viewControllers classes. Within this scope, 'enableAutoToolbar' property is ignored. Class should be kind of UIViewController.
     */
    @objc public var disabledToolbarClasses  = [UIViewController.Type]()

    /**
     Enable automatic toolbar creation within the scope of enabled toolbar viewControllers classes. Within this scope, 'enableAutoToolbar' property is ignored. Class should be kind of UIViewController. If same Class is added in disabledToolbarClasses list, then enabledToolbarClasses will be ignore.
     */
    @objc public var enabledToolbarClasses  = [UIViewController.Type]()

    /**
     Allowed subclasses of UIView to add all inner textField, this will allow to navigate between textField contains in different superview. Class should be kind of UIView.
     */
    @objc public var toolbarPreviousNextAllowedClasses  = [UIView.Type]()

    /**
     Disabled classes to ignore 'shouldResignOnTouchOutside' property, Class should be kind of UIViewController.
     */
    @objc public var disabledTouchResignedClasses  = [UIViewController.Type]()

    /**
     Enabled classes to forcefully enable 'shouldResignOnTouchOutsite' property. Class should be kind of UIViewController. If same Class is added in disabledTouchResignedClasses list, then enabledTouchResignedClasses will be ignored.
     */
    @objc public var enabledTouchResignedClasses  = [UIViewController.Type]()

    /**
     if shouldResignOnTouchOutside is enabled then you can customise the behaviour to not recognise gesture touches on some specific view subclasses. Class should be kind of UIView. Default is [UIControl, UINavigationBar]
     */
    @objc public var touchResignedGestureIgnoreClasses  = [UIView.Type]()

    // MARK: Third Party Library support
    /// Add TextField/TextView Notifications customised Notifications. For example while using YYTextView https://github.com/ibireme/YYText

    /**
    Add/Remove customised Notification for third party customised TextField/TextView. Please be aware that the Notification object must be idential to UITextField/UITextView Notification objects and customised TextField/TextView support must be idential to UITextField/UITextView.
    @param didBeginEditingNotificationName This should be identical to UITextViewTextDidBeginEditingNotification
    @param didEndEditingNotificationName This should be identical to UITextViewTextDidEndEditingNotification
    */

    @objc public func registerTextFieldViewClass(_ aClass: UIView.Type, didBeginEditingNotificationName: String, didEndEditingNotificationName: String) {

        NotificationCenter.default.addObserver(self, selector: #selector(self.textFieldViewDidBeginEditing(_:)), name: Notification.Name(rawValue: didBeginEditingNotificationName), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.textFieldViewDidEndEditing(_:)), name: Notification.Name(rawValue: didEndEditingNotificationName), object: nil)
    }

    @objc public func unregisterTextFieldViewClass(_ aClass: UIView.Type, didBeginEditingNotificationName: String, didEndEditingNotificationName: String) {

        NotificationCenter.default.removeObserver(self, name: Notification.Name(rawValue: didBeginEditingNotificationName), object: nil)
        NotificationCenter.default.removeObserver(self, name: Notification.Name(rawValue: didEndEditingNotificationName), object: nil)
    }

    /**************************************************************************************/
    internal struct WeakObjectContainer {
        weak var object: AnyObject?
    }

    /**************************************************************************************/

    // MARK: Initialization/Deinitialization

    /*  Singleton Object Initialization. */
    override init() {

        super.init()

        self.registerAllNotifications()

        //Creating gesture for @shouldResignOnTouchOutside. (Enhancement ID: #14)
        resignFirstResponderGesture.isEnabled = shouldResignOnTouchOutside

        //Loading IQToolbar, IQTitleBarButtonItem, IQBarButtonItem to fix first time keyboard appearance delay (Bug ID: #550)
        //If you experience exception breakpoint issue at below line then try these solutions https://stackoverflow.com/questions/27375640/all-exception-break-point-is-stopping-for-no-reason-on-simulator
        let textField = UITextField()
        textField.addDoneOnKeyboardWithTarget(nil, action: #selector(self.doneAction(_:)))
        textField.addPreviousNextDoneOnKeyboardWithTarget(nil, previousAction: #selector(self.previousAction(_:)), nextAction: #selector(self.nextAction(_:)), doneAction: #selector(self.doneAction(_:)))

        disabledDistanceHandlingClasses.append(UITableViewController.self)
        disabledDistanceHandlingClasses.append(UIAlertController.self)
        disabledToolbarClasses.append(UIAlertController.self)
        disabledTouchResignedClasses.append(UIAlertController.self)
        toolbarPreviousNextAllowedClasses.append(UITableView.self)
        toolbarPreviousNextAllowedClasses.append(UICollectionView.self)
        toolbarPreviousNextAllowedClasses.append(IQPreviousNextView.self)
        touchResignedGestureIgnoreClasses.append(UIControl.self)
        touchResignedGestureIgnoreClasses.append(UINavigationBar.self)
    }

    deinit {
        //  Disable the keyboard manager.
        enable = false

        //Removing notification observers on dealloc.
        NotificationCenter.default.removeObserver(self)
    }

    /** Getting keyWindow. */
    internal func keyWindow() -> UIWindow? {

        if let keyWindow = textFieldView?.window {
            return keyWindow
        } else {

            struct Static {
                /** @abstract   Save keyWindow object for reuse.
                @discussion Sometimes [[UIApplication sharedApplication] keyWindow] is returning nil between the app.   */
                static weak var keyWindow: UIWindow?
            }

            var originalKeyWindow: UIWindow?

            #if swift(>=5.1)
            if #available(iOS 13, *) {
                originalKeyWindow = UIApplication.shared.connectedScenes
                    .compactMap { $0 as? UIWindowScene }
                    .flatMap { $0.windows }
                    .first(where: { $0.isKeyWindow })
            } else {
                originalKeyWindow = UIApplication.shared.keyWindow
            }
            #else
            originalKeyWindow = UIApplication.shared.keyWindow
            #endif

            //If original key window is not nil and the cached keywindow is also not original keywindow then changing keywindow.
            if let originalKeyWindow = originalKeyWindow {
                Static.keyWindow = originalKeyWindow
            }

            //Return KeyWindow
            return Static.keyWindow
        }
    }

    // MARK: Public Methods

    /*  Refreshes textField/textView position if any external changes is explicitly made by user.   */
    @objc public func reloadLayoutIfNeeded() {

        guard privateIsEnabled(),
            keyboardShowing,
            topViewBeginOrigin.equalTo(IQKeyboardManager.kIQCGPointInvalid) == false, let textFieldView = textFieldView,
            textFieldView.isAlertViewTextField() == false else {
                return
        }
        optimizedAdjustPosition()
    }
}

extension IQKeyboardManager: UIGestureRecognizerDelegate {

    /** Resigning on tap gesture.   (Enhancement ID: #14)*/
    @objc internal func tapRecognized(_ gesture: UITapGestureRecognizer) {

        if gesture.state == .ended {

            //Resigning currently responder textField.
            resignFirstResponder()
        }
    }

    /** Note: returning YES is guaranteed to allow simultaneous recognition. returning NO is not guaranteed to prevent simultaneous recognition, as the other gesture's delegate may return YES. */
    @objc public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return false
    }

    /** To not detect touch events in a subclass of UIControl, these may have added their own selector for specific work */
    @objc public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        //  Should not recognize gesture if the clicked view is either UIControl or UINavigationBar(<Back button etc...)    (Bug ID: #145)

        for ignoreClass in touchResignedGestureIgnoreClasses {

            if touch.view?.isKind(of: ignoreClass) ?? false {
                return false
            }
        }

        return true
    }

}



public extension IQKeyboardManager {

    private struct AssociatedKeys {
        static var keyboardShowing = "keyboardShowing"
        static var keyboardShowNotification = "keyboardShowNotification"
        static var keyboardFrame = "keyboardFrame"
        static var animationDuration = "animationDuration"
        static var animationCurve = "animationCurve"
    }

    /**
     Boolean to know if keyboard is showing.
     */
    @objc private(set) var keyboardShowing: Bool {
        get {
            return objc_getAssociatedObject(self, &AssociatedKeys.keyboardShowing) as? Bool ?? false
        }
        set(newValue) {
            objc_setAssociatedObject(self, &AssociatedKeys.keyboardShowing, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }

    /** To save keyboardWillShowNotification. Needed for enable keyboard functionality. */
    internal var keyboardShowNotification: Notification? {
        get {
            return objc_getAssociatedObject(self, &AssociatedKeys.keyboardShowNotification) as? Notification
        }
        set(newValue) {
            objc_setAssociatedObject(self, &AssociatedKeys.keyboardShowNotification, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }

    /** To save keyboard rame. */
    internal var keyboardFrame: CGRect {
        get {
            return objc_getAssociatedObject(self, &AssociatedKeys.keyboardFrame) as? CGRect ?? .zero
        }
        set(newValue) {
            objc_setAssociatedObject(self, &AssociatedKeys.keyboardFrame, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }

    /** To save keyboard animation duration. */
    internal var animationDuration: TimeInterval {
        get {
            return objc_getAssociatedObject(self, &AssociatedKeys.animationDuration) as? TimeInterval ?? 0.25
        }
        set(newValue) {
            objc_setAssociatedObject(self, &AssociatedKeys.animationDuration, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }

    #if swift(>=4.2)
    typealias  UIViewAnimationOptions = UIView.AnimationOptions
    #endif

    /** To mimic the keyboard animation */
    internal var animationCurve: UIViewAnimationOptions {
        get {
            return objc_getAssociatedObject(self, &AssociatedKeys.animationCurve) as? UIViewAnimationOptions ?? .curveEaseOut
        }
        set(newValue) {
            objc_setAssociatedObject(self, &AssociatedKeys.animationCurve, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }

    /*  UIKeyboardWillShowNotification. */
    @objc internal func keyboardWillShow(_ notification: Notification?) {

        keyboardShowNotification = notification

        //  Boolean to know keyboard is showing/hiding
        keyboardShowing = true

        let oldKBFrame = keyboardFrame

        if let info = notification?.userInfo {

            //  Getting keyboard animation.
            if let curve = info[UIKeyboardAnimationCurveUserInfoKey] as? UInt {
                animationCurve = UIViewAnimationOptions(rawValue: curve).union(.beginFromCurrentState)
            } else {
                animationCurve = UIViewAnimationOptions.curveEaseOut.union(.beginFromCurrentState)
            }

            //  Getting keyboard animation duration
            animationDuration = info[UIKeyboardAnimationDurationUserInfoKey] as? TimeInterval ?? 0.25

            //  Getting UIKeyboardSize.
            if let kbFrame = info[UIKeyboardFrameEndUserInfoKey] as? CGRect {

                keyboardFrame = kbFrame
                showLog("UIKeyboard Frame: \(keyboardFrame)")
            }
        }

        guard privateIsEnabled() else {
            restorePosition()
            topViewBeginOrigin = IQKeyboardManager.kIQCGPointInvalid
            return
        }

        let startTime = CACurrentMediaTime()
        showLog("****** \(#function) started ******", indentation: 1)

        //  (Bug ID: #5)
        if let textFieldView = textFieldView, topViewBeginOrigin.equalTo(IQKeyboardManager.kIQCGPointInvalid) {

            //  keyboard is not showing(At the beginning only). We should save rootViewRect.
            rootViewController = textFieldView.parentContainerViewController()
            if let controller = rootViewController {

                if rootViewControllerWhilePopGestureRecognizerActive == controller {
                    topViewBeginOrigin = topViewBeginOriginWhilePopGestureRecognizerActive
                } else {
                    topViewBeginOrigin = controller.view.frame.origin
                }

                rootViewControllerWhilePopGestureRecognizerActive = nil
                topViewBeginOriginWhilePopGestureRecognizerActive = IQKeyboardManager.kIQCGPointInvalid

                self.showLog("Saving \(controller) beginning origin: \(self.topViewBeginOrigin)")
            }
        }

        //If last restored keyboard size is different(any orientation accure), then refresh. otherwise not.
        if keyboardFrame.equalTo(oldKBFrame) == false {

            //If textFieldView is inside UITableViewController then let UITableViewController to handle it (Bug ID: #37) (Bug ID: #76) See note:- https://developer.apple.com/library/ios/documentation/StringsTextFonts/Conceptual/TextAndWebiPhoneOS/KeyboardManagement/KeyboardManagement.html If it is UIAlertView textField then do not affect anything (Bug ID: #70).

            if keyboardShowing,
                let textFieldView = textFieldView,
                textFieldView.isAlertViewTextField() == false {

                //  keyboard is already showing. adjust position.
                optimizedAdjustPosition()
            }
        }

        let elapsedTime = CACurrentMediaTime() - startTime
        showLog("****** \(#function) ended: \(elapsedTime) seconds ******", indentation: -1)
    }

    /*  UIKeyboardDidShowNotification. */
    @objc internal func keyboardDidShow(_ notification: Notification?) {

        guard privateIsEnabled(),
            let textFieldView = textFieldView,
            let parentController = textFieldView.parentContainerViewController(), (parentController.modalPresentationStyle == UIModalPresentationStyle.formSheet || parentController.modalPresentationStyle == UIModalPresentationStyle.pageSheet),
            textFieldView.isAlertViewTextField() == false else {
                return
        }

        let startTime = CACurrentMediaTime()
        showLog("****** \(#function) started ******", indentation: 1)

        self.optimizedAdjustPosition()

        let elapsedTime = CACurrentMediaTime() - startTime
        showLog("****** \(#function) ended: \(elapsedTime) seconds ******", indentation: -1)
    }

    /*  UIKeyboardWillHideNotification. So setting rootViewController to it's default frame. */
    @objc internal func keyboardWillHide(_ notification: Notification?) {

        //If it's not a fake notification generated by [self setEnable:NO].
        if notification != nil {
            keyboardShowNotification = nil
        }

        //  Boolean to know keyboard is showing/hiding
        keyboardShowing = false

        if let info = notification?.userInfo {

            //  Getting keyboard animation.
            if let curve = info[UIKeyboardAnimationCurveUserInfoKey] as? UInt {
                animationCurve = UIViewAnimationOptions(rawValue: curve).union(.beginFromCurrentState)
            } else {
                animationCurve = UIViewAnimationOptions.curveEaseOut.union(.beginFromCurrentState)
            }

            //  Getting keyboard animation duration
            animationDuration = info[UIKeyboardAnimationDurationUserInfoKey] as? TimeInterval ?? 0.25
        }

        //If not enabled then do nothing.
        guard privateIsEnabled() else {
            return
        }

        let startTime = CACurrentMediaTime()
        showLog("****** \(#function) started ******", indentation: 1)

        //Commented due to #56. Added all the conditions below to handle WKWebView's textFields.    (Bug ID: #56)
        //  We are unable to get textField object while keyboard showing on WKWebView's textField.  (Bug ID: #11)
        //    if (_textFieldView == nil)   return

        //Restoring the contentOffset of the lastScrollView
        if let lastScrollView = lastScrollView {

            UIView.animate(withDuration: animationDuration, delay: 0, options: animationCurve, animations: { () -> Void in

                if lastScrollView.contentInset != self.startingContentInsets {
                    self.showLog("Restoring contentInset to: \(self.startingContentInsets)")
                    lastScrollView.contentInset = self.startingContentInsets
                    lastScrollView.scrollIndicatorInsets = self.startingScrollIndicatorInsets
                }

                if lastScrollView.shouldRestoreScrollViewContentOffset, !lastScrollView.contentOffset.equalTo(self.startingContentOffset) {
                    self.showLog("Restoring contentOffset to: \(self.startingContentOffset)")

                    var animatedContentOffset = false   //  (Bug ID: #1365, #1508, #1541)

                    if #available(iOS 9, *) {
                        animatedContentOffset = self.textFieldView?.superviewOfClassType(UIStackView.self, belowView: lastScrollView) != nil
                    }

                    if animatedContentOffset {
                        lastScrollView.setContentOffset(self.startingContentOffset, animated: UIView.areAnimationsEnabled)
                    } else {
                        lastScrollView.contentOffset = self.startingContentOffset
                    }
                }

                // TODO: restore scrollView state
                // This is temporary solution. Have to implement the save and restore scrollView state
                var superScrollView: UIScrollView? = lastScrollView

                while let scrollView = superScrollView {

                    let contentSize = CGSize(width: max(scrollView.contentSize.width, scrollView.frame.width), height: max(scrollView.contentSize.height, scrollView.frame.height))

                    let minimumY = contentSize.height - scrollView.frame.height

                    if minimumY < scrollView.contentOffset.y {

                        let newContentOffset = CGPoint(x: scrollView.contentOffset.x, y: minimumY)
                        if scrollView.contentOffset.equalTo(newContentOffset) == false {

                            var animatedContentOffset = false   //  (Bug ID: #1365, #1508, #1541)

                            if #available(iOS 9, *) {
                                animatedContentOffset = self.textFieldView?.superviewOfClassType(UIStackView.self, belowView: scrollView) != nil
                            }

                            if animatedContentOffset {
                                scrollView.setContentOffset(newContentOffset, animated: UIView.areAnimationsEnabled)
                            } else {
                                scrollView.contentOffset = newContentOffset
                            }

                            self.showLog("Restoring contentOffset to: \(self.startingContentOffset)")
                        }
                    }

                    superScrollView = scrollView.superviewOfClassType(UIScrollView.self) as? UIScrollView
                }
            })
        }

        restorePosition()

        //Reset all values
        lastScrollView = nil
        keyboardFrame = CGRect.zero
        startingContentInsets = UIEdgeInsets()
        startingScrollIndicatorInsets = UIEdgeInsets()
        startingContentOffset = CGPoint.zero
        //    topViewBeginRect = CGRectZero    //Commented due to #82

        let elapsedTime = CACurrentMediaTime() - startTime
        showLog("****** \(#function) ended: \(elapsedTime) seconds ******", indentation: -1)
    }

    @objc internal func keyboardDidHide(_ notification: Notification) {

        let startTime = CACurrentMediaTime()
        showLog("****** \(#function) started ******", indentation: 1)

        topViewBeginOrigin = IQKeyboardManager.kIQCGPointInvalid

        keyboardFrame = CGRect.zero

        let elapsedTime = CACurrentMediaTime() - startTime
        showLog("****** \(#function) ended: \(elapsedTime) seconds ******", indentation: -1)
    }
}

@objc public class IQPreviousNextView: UIView {

}