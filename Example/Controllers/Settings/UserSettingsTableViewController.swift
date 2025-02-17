import UIKit
import MiniApp

class UserSettingsTableViewController: RATTableViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate {

    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var editPhotoButton: UIButton!
    @IBOutlet weak var displayNameTextField: UITextField!
    @IBOutlet weak var modifyProfileSettingsButton: UIBarButtonItem!
    @IBOutlet weak var deletePhotoButton: UIButton!
    private var saveTitleText = MASDKLocale.localize("miniapp.sdk.ios.page.settings.userprofile.save")
    private var editTitleText = MASDKLocale.localize("miniapp.sdk.ios.page.settings.userprofile.edit")
    private var addTitleText = MASDKLocale.localize("miniapp.sdk.ios.page.settings.userprofile.add")
    private var removeTitleText = MASDKLocale.localize("miniapp.sdk.ios.page.settings.userprofile.remove")

    var userProfileImage: UIImage?

    override func viewDidLoad() {
        super.viewDidLoad()
        self.imageView.roundedCornerImageView()
        setProfileImage(image: retrieveProfileSettings())
        self.pageName = MASDKLocale.localize("demo.app.rat.page.name.usersettings")
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: false)
    }

    func setProfileImage(image: UIImage?) {
        guard let profileImage = image else {
            let imageConfig = UIImage.SymbolConfiguration(font: UIFont.systemFont(ofSize: 12, weight: .semibold))
            editPhotoButton.setImage(UIImage(systemName: "plus", withConfiguration: imageConfig), for: .normal)
            editPhotoButton.setTitle(addTitleText, for: .normal)

            deletePhotoButton.setImage(UIImage(systemName: "trash", withConfiguration: imageConfig), for: .normal)
            deletePhotoButton.setTitle(removeTitleText, for: .normal)
            return
        }
        editPhotoButton.setTitle(editTitleText, for: .normal)
        deletePhotoButton.setTitle(removeTitleText, for: .normal)
        self.imageView.image = profileImage
        self.userProfileImage = profileImage
    }

    @IBAction func openPhotoLibrary(_ sender: Any) {
        if modifyProfileSettingsButton.title == saveTitleText {
            showPhotoLibrary()
        }
    }

    @IBAction func showPhotoLibrary() {
        let imagePickerController = UIImagePickerController()
        imagePickerController.sourceType = .savedPhotosAlbum
        imagePickerController.allowsEditing = true
        imagePickerController.delegate = self
        present(imagePickerController, animated: true)
    }

    @IBAction func modifyProfileSettings() {
        if modifyProfileSettingsButton.title == editTitleText {
            modifyProfileSettingsButton.title = saveTitleText
        } else {
            if !saveProfileSettings() {
                return
            }
            modifyProfileSettingsButton.title = editTitleText
        }
        displayNameTextField.isEnabled = !displayNameTextField.isEnabled
        editPhotoButton.isEnabled = !editPhotoButton.isEnabled
        editPhotoButton.isHidden  = !editPhotoButton.isHidden
        deletePhotoButton.isEnabled = !deletePhotoButton.isEnabled
        deletePhotoButton.isHidden  = !deletePhotoButton.isHidden
        self.displayNameTextField.becomeFirstResponder()
    }

    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        picker.dismiss(animated: true)

        guard let image = info[.editedImage] as? UIImage else {
            log("User cancelled the operation")
            return
        }
        setProfileImage(image: image)
    }

    func saveProfileSettings(forKey key: String = "ProfileImage") -> Bool {
        displayNameTextField.text = displayNameTextField.text?.trimTrailingWhitespaces()
        return setProfileSettings(userDisplayName: displayNameTextField.text, profileImageURI: self.userProfileImage?.dataURI())
    }

    func retrieveProfileSettings(key: String = "ProfileImage") -> UIImage? {
        guard let userProfile = getProfileSettings() else {
            return nil
        }
        self.displayNameTextField.text = userProfile.displayName
        return userProfile.profileImageURI?.convertBase64ToImage()
    }

    @IBAction func deletePhotoPressed(_ sender: Any) {
        let rakutenImage = UIImage(named: "Rakuten")
        self.imageView.image = rakutenImage
        self.userProfileImage = rakutenImage
    }
}

extension UIImageView {
    func roundedCornerImageView() {
        self.layer.cornerRadius = self.frame.width/2
        self.layer.masksToBounds = true
    }
}
