//
//  InteractiveFlowResponse.swift
//
//
//  Created by Christian Rogobete on 08.01.25.
//

import Foundation
import stellarsdk

public class InteractiveFlowResponse {
    
    /// The anchor's internal ID for this deposit / withdrawal request. The wallet will use this ID to query the /transaction endpoint to check status of the request.
    public let id:String
    
    /// URL hosted by the anchor. The wallet should show this URL to the user as a popup.
    public let url:String
    
    /// Always set to interactive_customer_info_needed.
    public let type:String
    
    internal init(response:Sep24InteractiveResponse) {
        self.id = response.id
        self.url = response.url
        self.type = response.type
    }
    
}
