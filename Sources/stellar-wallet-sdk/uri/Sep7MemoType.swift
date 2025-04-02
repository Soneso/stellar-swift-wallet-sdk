//
//  Sep7MemoType.swift
//
//
//  Created by Christian Rogobete on 26.03.25.
//

import Foundation

public enum Sep7MemoType: String {
    case text = "MEMO_TEXT"
    case id = "MEMO_ID"
    case hash = "MEMO_HASH"
    case returnMemo = "MEMO_RETURN" // return is a keyword, so I had to rename it
}
