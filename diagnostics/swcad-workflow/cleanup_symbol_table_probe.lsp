;;; Read-only per-symbol-table probe for cleanup reopen diagnostics.

(vl-load-com)

(defun swapp-cleanup-symbol-probe-value (key / value)
  (setq value (swapp-state-value key))
  (if value value "<none>")
)

(setq swapp-cleanup-symbol-probe-path
  (strcat (getvar "DWGPREFIX") "swcad_cleanup_symbol_table_probe.txt")
)
(setq swapp-cleanup-symbol-probe-handle
  (open swapp-cleanup-symbol-probe-path "w")
)

(if swapp-cleanup-symbol-probe-handle
  (progn
    (write-line
      (strcat "CURRENT_LSP_VERSION=" *swapp-version*)
      swapp-cleanup-symbol-probe-handle
    )
    (write-line
      (strcat
        "STORED_TABLE_COUNT="
        (swapp-cleanup-symbol-probe-value "RESOURCE_CLEANUP_TABLE_COUNT")
      )
      swapp-cleanup-symbol-probe-handle
    )
    (write-line
      (strcat
        "STORED_DICTIONARY_COUNT="
        (swapp-cleanup-symbol-probe-value "RESOURCE_CLEANUP_DICTIONARY_COUNT")
      )
      swapp-cleanup-symbol-probe-handle
    )
    (setq swapp-cleanup-symbol-probe-total 0)
    (foreach swapp-cleanup-symbol-probe-table *swapp-purge-symbol-tables*
      (setq swapp-cleanup-symbol-probe-records nil)
      (setq swapp-cleanup-symbol-probe-item
        (swapp-safe-tblnext swapp-cleanup-symbol-probe-table T)
      )
      (while swapp-cleanup-symbol-probe-item
        (setq swapp-cleanup-symbol-probe-name
          (cdr (assoc 2 swapp-cleanup-symbol-probe-item))
        )
        (setq swapp-cleanup-symbol-probe-records
          (cons
            (strcat
              (if swapp-cleanup-symbol-probe-name
                swapp-cleanup-symbol-probe-name
                "<NO-NAME>"
              )
              "|"
              (if (cdr (assoc 5 swapp-cleanup-symbol-probe-item))
                (cdr (assoc 5 swapp-cleanup-symbol-probe-item))
                "<NO-HANDLE>"
              )
            )
            swapp-cleanup-symbol-probe-records
          )
        )
        (setq swapp-cleanup-symbol-probe-item
          (swapp-safe-tblnext swapp-cleanup-symbol-probe-table nil)
        )
      )
      (setq swapp-cleanup-symbol-probe-records
        (swapp-sort-strings swapp-cleanup-symbol-probe-records)
      )
      (setq swapp-cleanup-symbol-probe-total
        (+
          swapp-cleanup-symbol-probe-total
          (length swapp-cleanup-symbol-probe-records)
        )
      )
      (write-line
        (strcat
          "TABLE=" swapp-cleanup-symbol-probe-table
          " COUNT=" (itoa (length swapp-cleanup-symbol-probe-records))
        )
        swapp-cleanup-symbol-probe-handle
      )
      (foreach swapp-cleanup-symbol-probe-record
        swapp-cleanup-symbol-probe-records
        (write-line
          (strcat
            "  RECORD=" swapp-cleanup-symbol-probe-table
            "|" swapp-cleanup-symbol-probe-record
          )
          swapp-cleanup-symbol-probe-handle
        )
      )
    )
    (write-line
      (strcat "CURRENT_TABLE_COUNT=" (itoa swapp-cleanup-symbol-probe-total))
      swapp-cleanup-symbol-probe-handle
    )
    (close swapp-cleanup-symbol-probe-handle)
    (princ
      (strcat
        "\nCleanup symbol table probe: "
        swapp-cleanup-symbol-probe-path
      )
    )
  )
  (princ "\nCleanup symbol table probe failed to open its output file.")
)

(princ)
