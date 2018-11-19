;;; org-jekyll.el --- Publish org-mode to jekyll

;; Copyright (C) 2018 Kukjin Kang

;; Version: 0.0.1
;; Keywords: org-mode, jekyll
;; URL:

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:

;;; Code:


(require 'dash)
(require 'org)
(require 's)
(require 'kv)


(defgroup org-jekyll nil
  "Publish org-mode to jekyll"
  :tag "org-jekyll"
  :group 'org)


(defcustom org-jekyll-author nil
  "Author."
  :type 'string
  :group 'org-jekyell)


(defcustom org-jekyll-source-directory nil
  "Path to org files."
  :type 'string
  :group 'org-jekyell)


(defcustom org-jekyll-jekyll-directory nil
  "Path to jekyll."
  :type 'string
  :group 'org-jekyll)


(defcustom org-jekyll-jekyll-host "localhost"
  "Hostname for jekyll server."
  :type 'string
  :group 'org-jekyll)


(defcustom org-jekyll-jekyll-port 4000
  "Port for jekyll server."
  :type 'int
  :group 'org-jekyll)


(defcustom org-jekyll-github nil
  "Github URL."
  :type 'string
  :group 'org-jekyll)


;;;###autoload
(defun org-jekyll-github-open ()
  "Open github page."
  (interactive)
  (shell-command
   (format
    "open '%s'"
    org-jekyll-github)))


(defvar org-jekyll-jekyll-process nil
  "Jekyll server process.")


;;;###autoload
(defun org-jekyll-jekyll-serve ()
  "Start jekyll server.  If server is already running, stop and start."
  (interactive)
  (org-jekyll-jekyll-stop-serve)
  (setq org-jekyll-jekyll-process
	(start-process-shell-command
	 "jekyll-server"
	 "*jekyll-server*"
	 (format "cd %s; GEM_HOME=~/.gem bundle exec jekyll serve --host %s --port %s"
		 org-jekyll-jekyll-directory
		 org-jekyll-jekyll-host
		 org-jekyll-jekyll-port)))
  (message "Jekyll started."))


;;;###autoload
(defun org-jekyll-jekyll-stop-serve ()
  "Stop jekyll server."
  (interactive)
  (when org-jekyll-jekyll-process
    (delete-process org-jekyll-jekyll-process)
    (setq org-jekyll-jekyll-process nil)))


;;;###autoload
(defun org-jekyll-jekyll-open ()
  "Open the page provided the jekyll server in browser."
  (interactive)
  (shell-command
   (format "open 'http://%s:%s'"
	   org-jekyll-jekyll-host
	   org-jekyll-jekyll-port)))

(defun org-jekyll-org-template (layout
				author
				date
				title
				description
				tags
				categories)
  "Generate org tempalate.
LAYOUT, AUTHOR, DATE, TITLE, DESCRIPTION, TAGS, CATEGORIES."
  (format "#+STARTUP: showall
#+STARTUP: hidestars
#+OPTIONS: H:2 num:nil tags:nil toc:nil timestamps:t
#+LAYOUT: %s
#+AUTHOR: %s
#+DATE: %s
#+TITLE: %s
#+DESCRIPTION: %s
#+CATEGORIES: %s
#+TAGS: %s
\n"
	  layout
	  author
	  date
	  title
	  description
	  tags
	  categories))

(defun org-jekyll--read-layout ()
  "Read layout."
  (let ((prompt "Layout: ")
	(choices '("post")))
    (ido-completing-read prompt
			 choices
			 nil
			 'require-match)))

(defun org-jekyll--read-title ()
  "Read title."
  (read-string "Title: "))


(defun org-jekyll--read-description ()
  "Read description."
  (read-string "Description: "))


(defun org-jekyll--read-tags ()
  "Read tags."
  (read-string "Tags (csv): "))


(defun org-jekyll--read-categories ()
  "Read categories."
  (read-string "Categories (csv): "))


(defun org-jekyll-now ()
  "Return current datetime."
  (format-time-string "%Y-%m-%d %a %H:%M"))


(defun org-jekyll-read-metadata ()
  "Read metadata."
  (list
   :author      org-jekyll-author
   :date        (org-jekyll-now)
   :layout      (org-jekyll--read-layout)
   :title       (org-jekyll--read-title)
   :description (org-jekyll--read-description)
   :tags        (org-jekyll--read-tags)
   :categories  (org-jekyll--read-categories)))


;;;###autoload
(defun org-jekyll-insert-metadata ()
  "Insert metadata in current buffer."
  (interactive)
  (let* ((metadata    (org-jekyll-read-metadata))
	 (author      (plist-get metadata :author))
	 (date        (plist-get metadata :date))
	 (layout      (plist-get metadata :layout))
	 (title       (plist-get metadata :title))
	 (description (plist-get metadata :description))
	 (tags        (plist-get metadata :tags))
	 (categories  (plist-get metadata :categories)))
    (save-excursion
      (with-current-buffer (buffer-name)
	(goto-char (point-min))
	(insert (org-jekyll-org-template layout
					 author
					 date
					 title
					 description
					 tags
					 categories))))))


(defun org-jekyll--make-slug (s)
  "Make S to SLUG format."
  (->> s
       (replace-regexp-in-string "[\[\](){}~!#$^\\]" " ")
       downcase
       (replace-regexp-in-string " " "-")))


;;;###autoload
(defun org-jekyll-create-draft ()
  "Create draft."
  (interactive)
  (let* ((metadata    (org-jekyll-read-metadata))
	 (author      (plist-get metadata :author))
	 (date        (plist-get metadata :date))
	 (layout      (plist-get metadata :layout))
	 (title       (plist-get metadata :title))
	 (description (plist-get metadata :description))
	 (tags        (plist-get metadata :tags))
	 (categories  (plist-get metadata :categories))
	 (timestamp   (apply 'encode-time (org-parse-time-string date)))
	 (year        (format-time-string "%Y" timestamp))
	 (month       (format-time-string "%m" timestamp))
	 (day         (format-time-string "%d" timestamp))
	 (base-dir    (file-name-as-directory org-jekyll-source-directory))
	 (draft-file  (concat base-dir year "-" month "-" day "-" (org-jekyll--make-slug title) ".org")))
    (unless (file-exists-p base-dir)
      (make-directory base-dir t))
    (unless (file-exists-p draft-file)
      (with-temp-file draft-file
	(insert (org-jekyll-org-template layout
					 author
					 date
					 title
					 description
					 tags
					 categories))
	(insert "* ")))
    (find-file draft-file)))


(defun org-jekyll--read-options-from-buffer ()
  "Read options from buffer."
  (let ((special-line-regex "^#\\+\\(.+\\):[ \t]+\\(.+\\)$")
	(options-plist nil))
    (save-excursion
      (goto-char (point-min))
      (catch 'break
	(while t
	  (let ((current-line (buffer-substring-no-properties (line-beginning-position)
							      (line-end-position))))
	    (when (string-match special-line-regex current-line)
	      (let ((key   (intern (concat ":" (downcase (match-string 1 current-line)))))
		    (value (match-string 2 current-line)))
		(setq options-plist (plist-put options-plist key value))))
	    (unless (= 0 (forward-line))
	      (throw 'break nil))))))
    options-plist))


(defun org-jekyll--read-options (org-file)
  "Read options from ORG-FILE."
  (with-temp-buffer
    (when (file-exists-p org-file)
      (insert-file-contents org-file)
      (org-jekyll--read-options-from-buffer))))


(defun org-jekyll-read-options (org-file)
  "Read options from ORG-FILE."
  (org-jekyll--read-options org-file))


(defun org-jekyll-insert-options (options html-file)
  "Insert OPTIONS to HTML-FILE."
  (let* ((visiting    (find-buffer-visiting html-file))
	 (work-buffer (or visiting (find-file-noselect html-file)))
	 (layout      (plist-get options :layout))
	 (title       (plist-get options :title))
	 (categories  (plist-get options :categories))
	 (tags        (plist-get options :tags)))
    (save-excursion
      (with-current-buffer work-buffer
	(goto-char (point-min))
	(insert "---\n")
	(insert (format "layout: %s\n" layout))
	(insert (format "title: %s\n" title))
	(insert (format "categories: [%s]\n" categories))
	(insert (format "tags: [%s]\n" tags))
	(insert "---\n")
	(save-buffer))
      (unless visiting (kill-buffer work-buffer)))))


(defun org-jekyll-fix-image-links (html-file)
  "Modify image links in HTML-FILE."
  (let* ((visiting    (find-buffer-visiting html-file))
	 (work-buffer (or visiting (find-file-noselect html-file))))
    (save-match-data
      (save-excursion
	(with-current-buffer work-buffer
	  (goto-char (point-min))
	  (while (search-forward-regexp "src=\"[^\"]*.[png|jpg]\"" nil t 1)
	    (let ((matched (match-string 0)))
	      (message (format "====> %s" matched))
	      (replace-match
	       (concat
		"src=\""
		org-jekyll-github
		"/"
		"images"
		"/"
		(substring matched 5))))
	    (replace-match (match-string 0)))
	  (goto-char (point-min))
	  (while (search-forward-regexp "data=\"[^\"]*.[svg]\"" nil t 1)
	    (let ((matched (match-string 0)))
	      (message (format "====> %s" matched))
	      (replace-match
	       (concat
		"data=\""
		org-jekyll-github
		"/"
		"images"
		"/"
		(substring matched 6))))
	    (replace-match (match-string 0)))
	  (save-buffer))))
    (unless visiting (kill-buffer work-buffer))))


(defun org-jekyll-git-commit-and-push ()
  "Commit post and push to github."
  (interactive)
  (let ((default-directory org-jekyll-jekyll-directory))
    (shell-command "git commit _posts/* -m \"post commit\"")
    (shell-command "git push")))


(defun org-jekyll-publish-draft (org-file)
  "Publish ORG-FILE to HTML."
  (let* ((metadata  (org-jekyll-read-options org-file))
	 (html-file (concat
		     (file-name-as-directory org-jekyll-jekyll-directory)
		     "_posts"
		     "/"
		     (file-name-base org-file)
		     ".html")))
    (org-export-to-file 'html html-file nil nil nil t nil nil)
    (org-jekyll-insert-options metadata html-file)
    (org-jekyll-fix-image-links html-file)
    (message (format "%s published." html-file))))


;;;###autoload
(defun org-jekyll-publish-current-buffer ()
  "Publish current buffer."
  (interactive)
  (org-jekyll-publish-draft (buffer-file-name)))


(provide 'org-jekyll)

;;; org-jekyll.el ends here
