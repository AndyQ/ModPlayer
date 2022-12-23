//
//  Utils.m
//  MyVault
//
//  Created by Andy Qua on 03/10/2011.
//  Copyright (c) 2011 British Airways. All rights reserved.
//

import UIKit

func documentPath() -> URL {
    let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
    let documentsDirectory = paths[0]
    return documentsDirectory
}


extension UIViewController {
    func showAlert( title: String, message: String ) {
        let ac = UIAlertController(title: title, message: message, preferredStyle: .alert)
        
        ac.addAction(UIAlertAction(title: "OK", style: .cancel, handler: nil ))
        
        UIApplication.shared.delegate?.window??.rootViewController?.present(ac, animated: true, completion: nil)
    }
}
    
