;;; Read-only probe for a symbol-table block recreated after DWG reopen.

(vl-load-com)

(setq swapp-anon-probe-target "*U4501")
(setq swapp-anon-probe-path
  (strcat (getvar "DWGPREFIX") "swcad_cleanup_anonymous_block_probe.txt")
)

(defun swapp-anon-probe-safe (fn args / value)
  (setq value (vl-catch-all-apply fn args))
  (if (vl-catch-all-error-p value) nil value)
)

(defun swapp-anon-probe-string (value)
  (cond
    ((null value) "<none>")
    ((= (type value) 'STR) value)
    (T (vl-princ-to-string value))
  )
)

(defun swapp-anon-probe-bool (value)
  (if (= value :vlax-true) "yes" "no")
)

(defun swapp-anon-probe-point (value)
  (if value
    (vl-princ-to-string (vlax-safearray->list (vlax-variant-value value)))
    "<none>"
  )
)

(defun swapp-anon-probe-write (text)
  (if swapp-anon-probe-handle
    (write-line text swapp-anon-probe-handle)
  )
)

(defun swapp-anon-probe-reference-record (owner object / name effective handle insertion has-attributes dynamic)
  (setq name (swapp-anon-probe-safe 'vla-get-Name (list object)))
  (setq effective (swapp-anon-probe-safe 'vla-get-EffectiveName (list object)))
  (if
    (or
      (and name (= (strcase name) (strcase swapp-anon-probe-target)))
      (and effective (= (strcase effective) (strcase swapp-anon-probe-target)))
    )
    (progn
      (setq handle (swapp-anon-probe-safe 'vla-get-Handle (list object)))
      (setq insertion (swapp-anon-probe-safe 'vla-get-InsertionPoint (list object)))
      (setq has-attributes (swapp-anon-probe-safe 'vla-get-HasAttributes (list object)))
      (setq dynamic (swapp-anon-probe-safe 'vla-get-IsDynamicBlock (list object)))
      (swapp-anon-probe-write
        (strcat
          "REFERENCE owner=" owner
          " handle=" (swapp-anon-probe-string handle)
          " name=" (swapp-anon-probe-string name)
          " effective=" (swapp-anon-probe-string effective)
          " dynamic=" (swapp-anon-probe-bool dynamic)
          " attributes=" (swapp-anon-probe-bool has-attributes)
          " insertion=" (swapp-anon-probe-point insertion)
        )
      )
      1
    )
    0
  )
)

(setq swapp-anon-probe-handle (open swapp-anon-probe-path "w"))

(if swapp-anon-probe-handle
  (progn
    (setq swapp-anon-probe-definition
      (tblobjname "BLOCK" swapp-anon-probe-target)
    )
    (swapp-anon-probe-write
      (strcat "DWG=" (getvar "DWGPREFIX") (getvar "DWGNAME"))
    )
    (swapp-anon-probe-write
      (strcat "TARGET=" swapp-anon-probe-target)
    )
    (swapp-anon-probe-write
      (strcat
        "DEFINITION_EXISTS="
        (if swapp-anon-probe-definition "yes" "no")
      )
    )
    (if swapp-anon-probe-definition
      (progn
        (swapp-anon-probe-write
          (strcat
            "DEFINITION_ENTGET="
            (vl-princ-to-string
              (entget swapp-anon-probe-definition '("*"))
            )
          )
        )
        (setq swapp-anon-probe-block
          (swapp-anon-probe-safe
            'vla-Item
            (list
              (vla-get-Blocks (vla-get-ActiveDocument (vlax-get-acad-object)))
              swapp-anon-probe-target
            )
          )
        )
        (if swapp-anon-probe-block
          (swapp-anon-probe-write
            (strcat
              "DEFINITION_OBJECT"
              " count="
              (swapp-anon-probe-string
                (swapp-anon-probe-safe 'vla-get-Count (list swapp-anon-probe-block))
              )
              " layout="
              (swapp-anon-probe-bool
                (swapp-anon-probe-safe 'vla-get-IsLayout (list swapp-anon-probe-block))
              )
              " xref="
              (swapp-anon-probe-bool
                (swapp-anon-probe-safe 'vla-get-IsXRef (list swapp-anon-probe-block))
              )
            )
          )
        )
      )
    )
    (setq swapp-anon-probe-reference-count 0)
    (vlax-for swapp-anon-probe-owner
      (vla-get-Blocks (vla-get-ActiveDocument (vlax-get-acad-object)))
      (setq swapp-anon-probe-owner-name
        (swapp-anon-probe-string
          (swapp-anon-probe-safe 'vla-get-Name (list swapp-anon-probe-owner))
        )
      )
      (vlax-for swapp-anon-probe-object swapp-anon-probe-owner
        (if
          (wcmatch
            (strcase
              (swapp-anon-probe-string
                (swapp-anon-probe-safe
                  'vla-get-ObjectName
                  (list swapp-anon-probe-object)
                )
              )
            )
            "*BLOCKREFERENCE*"
          )
          (setq swapp-anon-probe-reference-count
            (+
              swapp-anon-probe-reference-count
              (swapp-anon-probe-reference-record
                swapp-anon-probe-owner-name
                swapp-anon-probe-object
              )
            )
          )
        )
      )
    )
    (swapp-anon-probe-write
      (strcat
        "REFERENCE_COUNT=" (itoa swapp-anon-probe-reference-count)
      )
    )
    (close swapp-anon-probe-handle)
    (setq swapp-anon-probe-handle nil)
    (princ
      (strcat "\nCleanup anonymous block probe: " swapp-anon-probe-path)
    )
  )
  (princ "\nCleanup anonymous block probe failed to open its output file.")
)

(princ)
