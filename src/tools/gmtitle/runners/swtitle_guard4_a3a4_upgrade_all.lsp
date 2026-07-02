;;; APPLOAD this file only on a work-copy DWG when you are ready to replace
;;; all listed A3/A4 non-native GMTITLE pairs with fresh native GMTITLE output.
;;;
;;; The command itself is guarded by swcad_title_scale.lsp:
;;; - it aborts outside Documents/CAD tool/work
;;; - it aborts if possible accidental command text is present
;;; - it asks for confirmation/count and opens the native GMTITLE dialogs

(vl-load-com)

(defun swtitle-guard4-runner-main-loaded-p ()
  (and
    (boundp '*swcad-title-scale-version*)
    (equal *swcad-title-scale-version* "260702-a3a4-strict-native-recheck-3")
  )
)

(defun swtitle-guard4-runner-load-main (/ user user-path self self-dir parent-dir candidates candidate found result)
  (if (swtitle-guard4-runner-main-loaded-p)
    T
    (progn
      (setq user (getenv "USERPROFILE"))
      (setq user-path (if user (vl-string-translate "\\" "/" user) nil))
      (setq self (findfile "swtitle_guard4_a3a4_upgrade_all.lsp"))
      (setq self-dir (if self (vl-filename-directory self) nil))
      (setq parent-dir (if self-dir (vl-filename-directory self-dir) nil))
      (setq candidates
        (append
          (if parent-dir
            (list (strcat parent-dir "/swcad_title_scale.lsp"))
            nil
          )
          (list
            "swcad_title_scale.lsp"
            "../swcad_title_scale.lsp"
            "src/tools/gmtitle/swcad_title_scale.lsp"
          )
          (if user-path
            (list
              (strcat user-path "/Documents/CAD tool/src/tools/gmtitle/swcad_title_scale.lsp")
              (strcat user-path "/Documents/CAD tool cloud/src/tools/gmtitle/swcad_title_scale.lsp")
            )
            nil
          )
        )
      )
      (setq found nil)
      (foreach candidate candidates
        (if (and candidate (not found))
          (setq found (findfile candidate))
        )
      )
      (if found
        (progn
          (setq result (vl-catch-all-apply 'load (list found)))
          (if (vl-catch-all-error-p result)
            (progn
              (princ (strcat "\nSWTITLE runner failed to load main LSP: " (vl-catch-all-error-message result)))
              nil
            )
            (if (swtitle-guard4-runner-main-loaded-p)
              T
              (progn
                (princ "\nSWTITLE runner loaded a main LSP, but it was not the current strict-native-recheck version. APPLOAD the current swcad_title_scale.lsp first.")
                nil
              )
            )
          )
        )
        (progn
          (princ "\nSWTITLE runner could not find swcad_title_scale.lsp. APPLOAD the main file first.")
          nil
        )
      )
    )
  )
)

(if (swtitle-guard4-runner-load-main)
  (c:SWTITLEUPGRADENATIVEA3A4ALL)
)
(princ)
