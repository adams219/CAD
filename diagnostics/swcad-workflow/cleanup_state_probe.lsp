;;; Read-only RESOURCE_CLEANUP state probe for GstarCAD CAD tests.

(vl-load-com)

(defun swapp-cleanup-probe-value (key / value)
  (setq value (swapp-state-value key))
  (if value value "<none>")
)

(defun swapp-cleanup-probe-write (handle key)
  (write-line
    (strcat key "=" (swapp-cleanup-probe-value key))
    handle
  )
)

(defun swapp-cleanup-probe-hex-key-p (key)
  (and
    key
    (> (strlen key) 0)
    (= (strlen (vl-string-trim "0123456789ABCDEF" (strcase key))) 0)
  )
)

(setq swapp-cleanup-probe-path
  (strcat (getvar "DWGPREFIX") "swcad_cleanup_state_probe.txt")
)
(setq swapp-cleanup-probe-handle (open swapp-cleanup-probe-path "w"))

(if swapp-cleanup-probe-handle
  (progn
    (foreach swapp-cleanup-probe-key
      '(
        "VERSION"
        "RESOURCE_CLEANUP"
        "RESOURCE_CLEANUP_POLICY"
        "RESOURCE_CLEANUP_DETAIL"
        "RESOURCE_CLEANUP_ROLLBACK"
        "RESOURCE_CLEANUP_PASSES"
        "RESOURCE_CLEANUP_REMOVED"
        "RESOURCE_CLEANUP_REMOVED_SAMPLE"
        "RESOURCE_CLEANUP_STABLE_REMOVED_SAMPLE"
        "RESOURCE_CLEANUP_POST_SAVE_REMOVED_IDENTITIES"
        "RESOURCE_CLEANUP_POST_SAVE_ADDED_IDENTITIES"
        "RESOURCE_CLEANUP_POST_SAVE_HANDLE_REREGISTERED"
        "RESOURCE_CLEANUP_STATE_SAVE_STABILIZATION_PASSES"
        "RESOURCE_CLEANUP_STATE_SAVE_REBASE_COUNT"
        "RESOURCE_CLEANUP_STATE_SAVE_REMOVED_SAMPLE"
        "RESOURCE_CLEANUP_STATE_SAVE_ADDED_SAMPLE"
        "RESOURCE_CLEANUP_STATE_SAVE_HANDLE_REREGISTERED"
        "RESOURCE_CLEANUP_DEFINITION_SIGNATURE"
        "RESOURCE_CLEANUP_DEFINITION_IDENTITY_SIGNATURE"
        "RESOURCE_CLEANUP_STABLE_DEFINITION_IDENTITY_SIGNATURE"
        "RESOURCE_CLEANUP_APPID_IDENTITY_SIGNATURE"
        "RESOURCE_CLEANUP_VPORT_IDENTITY_SIGNATURE"
        "RESOURCE_CLEANUP_SESSION_ANON_BLOCK_IDENTITY_SIGNATURE"
        "RESOURCE_CLEANUP_STABLE_IDENTITY_EXCLUDED"
        "RESOURCE_CLEANUP_INTEGRITY"
      )
      (swapp-cleanup-probe-write
        swapp-cleanup-probe-handle
        swapp-cleanup-probe-key
      )
    )
    (setq swapp-cleanup-probe-current-integrity
      (swapp-workflow-integrity-signature
        (swapp-workflow-integrity-snapshot)
      )
    )
    (setq swapp-cleanup-probe-current-definitions
      (swapp-named-definition-snapshot)
    )
    (setq swapp-cleanup-probe-workflow-state-record "<missing>")
    (setq swapp-cleanup-probe-no-key-count 0)
    (foreach swapp-cleanup-probe-definition-record
      (nth 2 swapp-cleanup-probe-current-definitions)
      (if
        (vl-string-search
          "DICT|NOD/SWCAD_WORKFLOW_STATE|XRECORD|"
          swapp-cleanup-probe-definition-record
        )
        (setq swapp-cleanup-probe-workflow-state-record
          swapp-cleanup-probe-definition-record
        )
      )
      (if
        (vl-string-search
          "<NO-KEY>"
          swapp-cleanup-probe-definition-record
        )
        (setq swapp-cleanup-probe-no-key-count
          (1+ swapp-cleanup-probe-no-key-count)
        )
      )
    )
    (write-line
      (strcat "CURRENT_INTEGRITY=" swapp-cleanup-probe-current-integrity)
      swapp-cleanup-probe-handle
    )
    (write-line
      (strcat
        "CURRENT_DEFINITION_SIGNATURE="
        (swapp-named-definition-signature
          swapp-cleanup-probe-current-definitions
        )
      )
      swapp-cleanup-probe-handle
    )
    (write-line
      (strcat
        "CURRENT_DEFINITION_IDENTITY_SIGNATURE="
        (swapp-named-definition-identity-signature
          swapp-cleanup-probe-current-definitions
        )
      )
      swapp-cleanup-probe-handle
    )
    (write-line
      (strcat
        "CURRENT_STABLE_DEFINITION_IDENTITY_SIGNATURE="
        (swapp-named-definition-stable-identity-signature
          swapp-cleanup-probe-current-definitions
        )
      )
      swapp-cleanup-probe-handle
    )
    (write-line
      (strcat
        "CURRENT_APPID_IDENTITY_SIGNATURE="
        (swapp-named-definition-appid-identity-signature
          swapp-cleanup-probe-current-definitions
        )
      )
      swapp-cleanup-probe-handle
    )
    (write-line
      (strcat
        "CURRENT_VPORT_IDENTITY_SIGNATURE="
        (swapp-named-definition-vport-identity-signature
          swapp-cleanup-probe-current-definitions
        )
      )
      swapp-cleanup-probe-handle
    )
    (write-line
      (strcat
        "CURRENT_SESSION_ANON_BLOCK_IDENTITY_SIGNATURE="
        (swapp-named-definition-session-anonymous-block-identity-signature
          swapp-cleanup-probe-current-definitions
        )
      )
      swapp-cleanup-probe-handle
    )
    (write-line
      (strcat
        "CURRENT_WORKFLOW_STATE_RECORD="
        swapp-cleanup-probe-workflow-state-record
      )
      swapp-cleanup-probe-handle
    )
    (write-line
      (strcat
        "CURRENT_NO_KEY_RECORD_COUNT="
        (itoa swapp-cleanup-probe-no-key-count)
      )
      swapp-cleanup-probe-handle
    )
    (write-line
      (strcat
        "RESOURCE_CLEANUP_VERIFY="
        (if (swapp-resource-cleanup-verify) "OK" "FAIL")
      )
      swapp-cleanup-probe-handle
    )
    (write-line
      (strcat "CURRENT_LSP_VERSION=" *swapp-version*)
      swapp-cleanup-probe-handle
    )
    (write-line
      (strcat
        "RESOURCE_CLEANUP_RETRY_ALLOWED="
        (if (swapp-resource-cleanup-retry-allowed-p) "YES" "NO")
      )
      swapp-cleanup-probe-handle
    )
    (write-line
      (strcat
        "RECOMMENDED_ACTION="
        (swapp-recommended-next-action
          (swapp-workflow-stage)
          (swapp-title-last-status)
        )
      )
      swapp-cleanup-probe-handle
    )
    (write-line "NOD_HEX_XRECORDS_BEGIN" swapp-cleanup-probe-handle)
    (foreach swapp-cleanup-probe-entry
      (swapp-dictionary-entries (namedobjdict))
      (if
        (and
          (swapp-cleanup-probe-hex-key-p (nth 0 swapp-cleanup-probe-entry))
          (equal (strcase (nth 2 swapp-cleanup-probe-entry)) "XRECORD")
        )
        (write-line
          (strcat
            "KEY=" (nth 0 swapp-cleanup-probe-entry)
            " HANDLE=" (nth 3 swapp-cleanup-probe-entry)
            " DATA="
            (vl-princ-to-string
              (entget (nth 1 swapp-cleanup-probe-entry))
            )
          )
          swapp-cleanup-probe-handle
        )
      )
    )
    (write-line "NOD_HEX_XRECORDS_END" swapp-cleanup-probe-handle)
    (write-line
      (strcat
        "NOD_ENTGET="
        (vl-princ-to-string (entget (namedobjdict)))
      )
      swapp-cleanup-probe-handle
    )
    (write-line "NOD_DICTNEXT_RAW_BEGIN" swapp-cleanup-probe-handle)
    (setq swapp-cleanup-probe-raw-item
      (swapp-safe-dictnext (namedobjdict) T)
    )
    (while swapp-cleanup-probe-raw-item
      (write-line
        (strcat
          "ITEM="
          (vl-princ-to-string swapp-cleanup-probe-raw-item)
        )
        swapp-cleanup-probe-handle
      )
      (setq swapp-cleanup-probe-raw-item
        (swapp-safe-dictnext (namedobjdict) nil)
      )
    )
    (write-line "NOD_DICTNEXT_RAW_END" swapp-cleanup-probe-handle)
    (close swapp-cleanup-probe-handle)
    (princ (strcat "\nCleanup state probe: " swapp-cleanup-probe-path))
  )
  (princ "\nCleanup state probe failed to open its output file.")
)

(princ)
