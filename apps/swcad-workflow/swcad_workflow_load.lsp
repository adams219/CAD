;;; SWCAD Workflow loader.

(vl-load-com)

(setq *swapp-loader-version* "260715-full-unused-purge-13")

(defun swapp-loader-source (/ source)
  (setq source nil)
  (if
    (and
      (boundp '*load-truename*)
      *load-truename*
      (= (type *load-truename*) 'STR)
    )
    (setq source *load-truename*)
  )
  (if (not source)
    (setq source (findfile "swcad_workflow_load.lsp"))
  )
  source
)

(defun swapp-loader-parent (path / clean)
  (setq clean (if path (vl-string-right-trim "\\/" path) nil))
  (if clean (vl-filename-directory clean) nil)
)

(defun swapp-loader-root-valid-p (root)
  (and
    root
    (= (type root) 'STR)
    (findfile (strcat root "/apps/swcad-workflow/swcad_workflow.lsp"))
    (findfile (strcat root "/src/tools/gmtitle/swcad_title_scale.lsp"))
  )
)

(defun swapp-loader-root (/ source app-dir apps-dir derived env-root user-root)
  (setq source (swapp-loader-source))
  (setq app-dir (if source (vl-filename-directory source) nil))
  (setq apps-dir (swapp-loader-parent app-dir))
  (setq derived (swapp-loader-parent apps-dir))
  (setq env-root (getenv "SWCAD_WORKFLOW_ROOT"))
  (setq user-root
    (if (getenv "USERPROFILE")
      (strcat (getenv "USERPROFILE") "/Documents/CAD tool")
      nil
    )
  )
  (cond
    ((swapp-loader-root-valid-p derived) derived)
    ((swapp-loader-root-valid-p env-root) env-root)
    ((swapp-loader-root-valid-p user-root) user-root)
    (T nil)
  )
)

(setq *swapp-root* (swapp-loader-root))

(defun swapp-loader-path (relative)
  (if *swapp-root* (strcat *swapp-root* "/" relative) nil)
)

(defun swapp-loader-load (relative / path result)
  (setq path (swapp-loader-path relative))
  (cond
    ((or (not path) (not (findfile path)))
      (princ (strcat "\nSWCAD Workflow module missing: " relative))
      nil
    )
    (T
      (setq result (vl-catch-all-apply 'load (list path)))
      (if (vl-catch-all-error-p result)
        (progn
          (princ (strcat "\nSWCAD Workflow module load failed: " relative))
          (princ (strcat "\n  " (vl-catch-all-error-message result)))
          nil
        )
        T
      )
    )
  )
)

(princ (strcat "\nSWCAD Workflow loading " *swapp-loader-version* "..."))

(if
  (and
    (swapp-loader-load "src/tools/gmtitle/swcad_title_scale.lsp")
    (swapp-loader-load "src/tools/gstarcad-dimstyle/gstarcad_dimstyle_keep_tolerance.lsp")
    (swapp-loader-load "src/tools/gstarcad-layout/gstarcad_layout_from_model.lsp")
    (swapp-loader-load "apps/swcad-workflow/swcad_workflow.lsp")
  )
  (progn
    (princ "\nSWCAD Workflow ready.")
    (princ "\nCommands: SWCADSTATUS, SWCADRUN, SWCADVERIFY")
  )
  (princ "\nSWCAD Workflow did not load completely. Review the missing/failed module above.")
)

(princ)
