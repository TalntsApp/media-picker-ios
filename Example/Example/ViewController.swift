//
//  ViewController.swift
//  Example
//
//  Created by Mikhail Stepkin on 26.02.16.
//  Copyright © 2016 Ramotion. All rights reserved.
//

import UIKit
import MediaPicker

class ViewController: UIViewController {
    
    @IBOutlet var mediaPicker: MediaPicker!

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        self.childViewControllers.forEach {
            $0.viewDidLayoutSubviews()
        }
    }


}

