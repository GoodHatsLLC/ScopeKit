import Foundation

public enum AttachmentError: Error {
    case circularAttachment
    case alreadyAttached
    case deallocatedHost
}
