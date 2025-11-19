#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint cupertino_native_plus.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'cupertino_native_plus'
  s.version          = '0.0.1'
  s.summary          = 'Native Liquid Glass widgets for iOS and macOS with pixel-perfect fidelity.'
  s.description      = <<-DESC
Native Liquid Glass widgets for iOS and macOS in Flutter with pixel-perfect fidelity.
                       DESC
  s.homepage         = 'https://github.com/NarekManukyan/cupertino_native_plus'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Narek Manukyan' => 'narek.manukyan.2031@gmail.com' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.dependency 'Flutter'
  s.dependency 'SVGKit', '~> 3.0'
  s.platform = :ios, '13.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'

  # If your plugin requires a privacy manifest, for example if it uses any
  # required reason APIs, update the PrivacyInfo.xcprivacy file to describe your
  # plugin's privacy impact, and then uncomment this line. For more information,
  # see https://developer.apple.com/documentation/bundleresources/privacy_manifest_files
  # s.resource_bundles = {'cupertino_native_plus_privacy' => ['Resources/PrivacyInfo.xcprivacy']}
end
