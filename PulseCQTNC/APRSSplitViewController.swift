//
//  APRSSplitViewController.swift
//  PulseModemA
//
//  Created by Pulsely on 7/29/18.
//  Copyright © 2018 Pulsely. All rights reserved.
//

import UIKit

class APRSSplitViewController: UISplitViewController, UISplitViewControllerDelegate {

    override func viewDidLoad() {
        super.viewDidLoad()

        self.delegate = self
        //splitViewController?.delegate = self

        self.preferredDisplayMode = .allVisible

    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */
    
    /*
    func splitViewController(splitViewController: UISplitViewController, collapseSecondaryViewController secondaryViewController: UIViewController!, ontoPrimaryViewController primaryViewController: UIViewController!) -> Bool{
        return true
    }
 */
    
    // https://stackoverflow.com/questions/25875618/uisplitviewcontroller-in-portrait-on-iphone-shows-detail-vc-instead-of-master
    func splitViewController(splitViewController: UISplitViewController,
                             collapseSecondaryViewController secondaryViewController: UIViewController!,
                             ontoPrimaryViewController primaryViewController: UIViewController!) -> Bool{
        return true
    }

    // Start with split view controller as Master
    // https://stackoverflow.com/questions/29506713/open-uisplitviewcontroller-to-master-view-rather-than-detail
    func splitViewController(
        _ splitViewController: UISplitViewController,
        collapseSecondary secondaryViewController: UIViewController,
        onto primaryViewController: UIViewController) -> Bool {
        // Return true to prevent UIKit from applying its default behavior
        return true
    }


}
