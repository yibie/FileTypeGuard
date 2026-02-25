FileTypeGuard - Stop Apps From Hijacking Your File Associations

**[Flair]** Free / Open Source

**Problem** You right-click a `.md` file, choose "Always Open With" your favorite editor, and it works — until the next app install or update silently overrides it. Now your Markdown files open in Xcode or some random app. You fix it again. It breaks again. The same thing happens with `.mp4`, `.avi`, and other media formats — every video player wants to be the default. macOS offers no way to lock these preferences permanently. FileTypeGuard does.

**Comparison** There's no real alternative for this on macOS. You can manually reset defaults in Finder's "Get Info" or use `duti` from the command line, but nothing monitors and auto-restores in real time. FileTypeGuard runs in the background and reverts unauthorized changes within seconds.

Other core features:

- Lock any file extension to your preferred app
- Real-time monitoring of the Launch Services database
- Event logging with full change history
- System notifications when associations are restored
- Localized in EN / JA / zh-Hans / zh-Hant


**Pricing** Free and open source 
GitHub: https://github.com/yibie/FileTypeGuard

**AI** AI Disclaimer: Claude assisted with i18n and boilerplate code
