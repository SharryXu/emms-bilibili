;;; emms-bilibili.el --- Play Bilibili in EMMS.

;; Authors: Tristan <huangtc@outlook.com>, stardiviner <numbchild@gmail.com>
;; Package-Requires: ((emacs "25") (cl-lib "0.5") (magit-popup "2.4.0") (emms "4.4") (emms-player-mpv "0.0.12"))
;; Package-Version: 0.1
;; Keywords: emms bilibili
;; homepage: https://github.com/stardiviner/emms-bilibili

;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs.  If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:

;; QUickstart:

;; 1) Add your directory to load path
;; (add-to-load-path "~/vcs/emms-bilibili")
;;
;; 2) import emms-bilibill
;; (require 'emms-bilibili)
;;
;; 3) run it
;; [M-x emms-bilibili]

;;; Code:


(require 'cl-lib)
(require 'url)
(require 'json)
(require 'emms)
(require 'emms-browser)
(require 'emms-source-playlist)
(require 'emms-mark)

(require 'emms-bilibili-download)

;; init
(defgroup emms-bilibili nil
  "Play your Bilibili favourite videos in EMMS."
  :prefix "emms-bilibili-"
  :group 'emms)

(defcustom emms-bilibili-mid nil
  "User mid."
  :type 'number
  :group 'emms-bilibili)

(defvar emms-bilibili-alist nil
  "Video info list.")

;; hooks
(defvar emms-bilibili-response-received-hook nil)

;; ssl magic
;; (setq tls-program '("openssl s_client -connect %h:%p -no_ssl2 -ign_eof"))

(defun emms-bilibili-get-mid ()
  "Prompt user for mid."
  (unless (not (null emms-bilibili-mid))
    (browse-url "https://space.bilibili.com/")
    (setq emms-bilibili-mid (read-from-minibuffer "Input your Bilibili user mid number: "))))

(defun emms-bilibili-url-clean-response-buffer ()
  "Delete header from response buffer."
  (goto-char (point-min))
  (re-search-forward "^$")
  (delete-region (point) (point-min))
  (delete-blank-lines))

(cl-defun emms-bilibili-generate-bookmark-url (vmid &optional (page 1) (pagesize 30))
  "Generate bookmark URL."
  (format
   "https://api.bilibili.com/x/v2/fav/video?vmid=%s&pn=%s&ps=%s&order=fav_time"
   vmid page pagesize))

(defun emms-bilibili-generate-video-url (aid)
  "Generate video URL from `AID'."
  (format "https://www.bilibili.com/video/av%d/" aid))

(defun emms-bilibili-insert-track (element)
  "Create track and insert `ELEMENT' into emms-playlist."
  (let* ((title (alist-get 'title element))
         (artist (alist-get 'name (alist-get 'owner element)))
         (duration (alist-get 'duration element))
         (url (emms-bilibili-generate-video-url (alist-get 'aid element)))
         (state (alist-get 'state element))
         (track (emms-track 'url url)))
    (when (>= state 0)
      (emms-track-set track 'info-title title)
      (emms-track-set track 'info-artist artist)
      (emms-track-set track 'info-playing-time duration)
      (with-current-emms-playlist
        (emms-playlist-insert-track track)))))

(cl-defun emms-bilibili-sync-playlist (&optional (page 1))
  "Sync Bilibili playlist to EMMS."
  (if (equal page nil)
      nil
    (url-retrieve
     (emms-bilibili-generate-bookmark-url emms-bilibili-mid page)
     (lambda (status)
       (let ((res (current-buffer))
             (json-array-type 'list))
         (with-current-buffer res
           (emms-bilibili-url-clean-response-buffer)
           (let* ((json-raw (json-read-from-string (decode-coding-string (buffer-string) 'utf-8)))
                  (pagecount (alist-get 'pagecount (alist-get 'data json-raw)))
                  (current-page (alist-get 'page (alist-get 'data json-raw)))
                  (data (assoc 'data json-raw))
                  )
             (when (= current-page 1)
               (setq emms-bilibili-alist nil))
             (setq emms-bilibili-alist (append emms-bilibili-alist (alist-get 'archives data)))
             (message "EMMS Bilibili bookmark page [%d/%d]" current-page pagecount)
             (if (= pagecount current-page)
                 (run-hooks 'emms-bilibili-response-received-hook)
               (emms-bilibili-sync-playlist (+ current-page 1))))))))))

;; add hook
(add-hook 'emms-bilibili-response-received-hook
          (lambda () (mapcar 'emms-bilibili-insert-track emms-bilibili-alist)))
(add-hook 'emms-bilibili-response-received-hook
          (lambda () (message "EMMS Bilibili fetch playlist done.")))

;;;###autoload
(defun emms-bilibili ()
  "Start emms-bilibili.

If the current buffer is an EMMS playlist buffer, make it the
main EMMS playlist buffer."
  (interactive)
  (when (and emms-playlist-buffer-p
             (not (eq (current-buffer) emms-playlist-buffer)))
    (emms-playlist-set-playlist-buffer (current-buffer)))
  (when (null emms-bilibili-mid)
    (emms-bilibili-get-mid))
  (with-current-emms-playlist
    (emms-playlist-clear)
    (emms-bilibili-sync-playlist))
  ;; auto open *EMMS Playlist* buffer.
  (emms))



(provide 'emms-bilibili)

;;; emms-bilibili.el ends here
