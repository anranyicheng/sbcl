(defun check-float-file (name)
  (with-open-file (stream name :if-does-not-exist nil)
    (when stream
      (format t "; Checking ~S~%" (pathname stream))
      ;; Ensure that we're reading the correct variant of the file
      ;; in case there is more than one set of floating-point formats.
      (assert (eq (read stream) :default))
      (sb-kernel::with-float-traps-masked (:overflow :divide-by-zero)
        (let ((*readtable* (copy-readtable)))
          ;; No need to do a full-blown read-time-eval.
          (set-dispatch-macro-character
              #\# #\. (lambda (stream subchar arg)
                        (declare (ignore subchar arg))
                        (let ((expr (read stream t nil t)))
                          (ecase (car expr)
                            (s (sb-kernel:make-single-float (second expr)))
                            (d (sb-kernel:make-double-float (second expr) (third expr)))))))
          (dolist (expr (read stream))
            (destructuring-bind (fun args . result) expr
              (let ((actual (if (eql fun 'read-from-string)
                                (let ((*read-default-float-format* (car args)))
                                  (multiple-value-list (apply fun (sb-int:ensure-list (cdr args)))))
                                (multiple-value-list (apply fun (sb-int:ensure-list args))))))
                (labels ((eqal (x y) ; non-ideal name, but other names are also non-ideal
                           (etypecase x
                             (cons (and (consp y) (eqal (car x) (car y)) (eqal (cdr x) (cdr y))))
                             (symbol (eql x y))
                             (rational (eql x y))
                             (float (eql x y))
                             (string (string= x y)))))
                  (unless (eqal actual result)
                    (cerror "Continue"
                            "FLOAT CACHE LINE ~S vs COMPUTED ~S~%"
                            expr actual)))))))))))

(compile 'check-float-file)
