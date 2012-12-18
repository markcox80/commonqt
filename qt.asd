(defpackage :qt-system
  (:use :cl :asdf))

(in-package :qt-system)

(eval-when (:compile-toplevel :load-toplevel :execute)
  (asdf:oos 'asdf:load-op :trivial-features))

;;; .cpp

(defclass cpp->so (source-file)
  ())

(defmethod source-file-type ((c cpp->so) (s module)) "cpp")

(defmethod output-files ((operation compile-op) (c cpp->so))
  (values
    (loop for filename in '("libcommonqt.so" "libcommonqt.so.1"
                            "libcommonqt.so.1.0" "libcommonqt.so.1.0.0")
          collect (merge-pathnames filename (component-pathname c)))
    ;; libcommonqt.so* files are never moved to separate FASL directory
    t))

(defmethod perform ((o load-op) (c cpp->so))
  t)

(defmethod perform ((o compile-op) (c cpp->so))
  (unless (operation-done-p o c)
    (when (find-package :qt)
      (set (find-symbol "*LOADED*" :qt) nil))
    (unless (zerop (run-shell-command
                    "if which gmake; then gmake -C ~S; else make -C ~:*~S; fi"
                    (namestring
                     (make-pathname :name nil
                                    :type nil
                                    :defaults (component-pathname c)))))
      (error 'operation-error :component c :operation o))))


;;; qmake

(defclass makefile (source-file)
  ())

(defmethod source-file-type ((c makefile) (s module)) nil)

;; we use :AROUND here as there's often another :AROUND method on ASDF:OUTPUT-FILES
;; that places the output into some FASL directory
(defmethod output-files :around ((operation compile-op) (c makefile))
  (list (make-pathname :name "Makefile"
		       :type nil
		       :defaults (component-pathname c))))

(defmethod perform ((o load-op) (c makefile))
  t)

(defmethod perform ((o compile-op) (c makefile))
  (unless (operation-done-p o c)
    (when (find-package :qt)
      (set (find-symbol "*LOADED*" :qt) nil))
    (unless (zerop (run-shell-command
                    "qmake ~A~S -o ~S"
                    #+darwin "-spec macx-g++ " #-darwin ""
                    (namestring
		     (merge-pathnames "commonqt.pro" (component-pathname c)))
                    (namestring (output-file o c))))
      (error 'operation-error :component c :operation o))))


;;; system

(defsystem :qt
    :serial t
    :components (#-(or mswindows windows win32) (makefile "commonqt.pro")
                 #-(or mswindows windows win32) (cpp->so "commonqt")
                 (:file "package")
                 (:file "utils")
                 (:file "ffi")
                 (:file "reader")
                 (:file "meta-classes")
                 (:file "classes")
                 (:file "marshal")
                 (:file "unmarshal")
                 (:file "primitive-call")
                 (:file "info")
                 (:file "call")
                 (:file "qvariant")
                 (:file "meta")
                 (:file "property")
                 (:file "qlist")
                 (:file "qapp")
                 (:file "connect"))
    :defsystem-depends-on (:trivial-features)
    :depends-on (:cffi :named-readtables :cl-ppcre :alexandria :closer-mop
                       :iterate :trivial-garbage #+darwin :bordeaux-threads))
