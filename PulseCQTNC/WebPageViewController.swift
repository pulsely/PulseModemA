//
//  WebPageViewController.swift
//  PulseModemA
//
//  Created by Pulsely on 8/2/18.
//  Copyright © 2018 Pulsely. All rights reserved.
//

import UIKit

var myContext = 50

class WebPageViewController: UIViewController {
    @IBOutlet weak var webview: UIWebView!
    
    var callsign:String = "-"
    var progressView: UIProgressView!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        self.title = callsign
        
        //add progresbar to navigation bar
        progressView = UIProgressView(progressViewStyle: .default)
        
        loadWebpage()
    }
    
    func loadWebpage() {
        var u = "https://qrz.com/db/" + callsign + "/"
        //webView.delegate = self
        webview.loadRequest(URLRequest(url: URL(string: u)!))
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

}
