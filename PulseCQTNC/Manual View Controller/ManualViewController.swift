//
//  ManualViewController.swift
//  PulseModemA
//
//  Created by Pulsely on 7/29/18.
//  Copyright © 2018 Pulsely. All rights reserved.
//

import UIKit

class ManualViewController: UIViewController, UIWebViewDelegate {
    @IBOutlet weak var webview: UIWebView!
    var d: NSDictionary = [:]
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let file_path: String = self.d.object(forKey: "file_path") as! String;
        let html_file = Bundle.main.url(forResource: file_path, withExtension: "html")!
        
        //let u : URL = URL(string: html_file)!
        let r : URLRequest = URLRequest(url: html_file)
        webview.loadRequest( r )
        
        //UIWebView.loadRequest(webView)()
        self.title = self.d.object( forKey: "title" ) as? String

    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
}

