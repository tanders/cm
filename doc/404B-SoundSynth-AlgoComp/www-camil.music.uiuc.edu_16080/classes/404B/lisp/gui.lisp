(in-package :CM)

;;; X11.app needs to be running before any GUI tools are opened.

;;; The CMIO (CM Input/Output) window:

(cmio)

(cmio :score '(:events (bar 23)) 
      :midi '(:score "hiho.mid" :microtuning :divisions))



(plotter '(0 0 .25 1.0 .5 .74 1 ) )

(defparameter pw
  (plotter (loop for x from 0 by 1 repeat 10
              collect (new midi :time x :duration 1
                           :keynum (between 60  80)))))

(defparameter pw
  (plotter (loop for x from 0 by 1 repeat 10
              collect (new midi :time x :duration 1
                           :keynum (between 60 80)))
           :y-axis (axis :keynum :minimum 60 :maximum  84 
                         :slot 'keynum )))
(defparameter pw
  (plotter (loop for x from 0 by 1 repeat 10
              collect (new midi :time x :duration 1
                           :keynum (between 60  80)))
           :x-axis (axis :seconds :slot '(time duration))
           :y-axis (axis :keynum :minimum 60 :maximum  84
                         :slot 'keynum)
           :view :box))

(plotter-data pw)

;;; plotter can hold multiple layers
              
(defparameter pw
  (plotter :zoom .5
           (loop for x from 0 to 1 by .2
                 for y = (random 1.0)
                 collect x collect y)
           (loop for x from 0 to 1 by 1/10
                 for y from 0 to 1 by 1/10
                 collect x collect y)
           (loop for x from 0 to 1 by .25
                 for y = (expt 10 (- x))
                 collect x collect y)))

(plotter-data pw)
(plotter-data pw :layer :front)

(defparameter pw
  (let* ((maxh 0)
         (hist (make-list 100 :initial-element 0))
         (rans (loop for x from 0 below 100
                     for y = (floor (+ (random 100)
                                       (random 100) )
                                    2)
                     collect x collect y
                     do (incf (elt hist y))
                     (setf maxh (max (elt hist y) maxh))))
         (bars (loop for y in hist for x from 0
                     when (> y 0) collect x
                     and collect (* (/ y maxh) 100))))
    (plotter :title "Mean distribution and histogram"
             :x-axis (axis :percentage)
             :y-axis (axis :percentage)
             :view '(:point :bar)
             :color '("plum4" "dark red")
             :point-size 6           
             rans
             bars)))

;;;
;;; defining new axes

(defaxis :unary ()
  :minimum -1 :maximum 1
  :increment 1/2
  :labeler "~,2F"
  :ticks-per-increment 2)

(defaxis :radians ()
  :minimum 0 :maximum (* pi 2)
  :increment (/ pi 2)
  :ticks-per-increment 2
  :labeler (lambda (x)
             (format nil "~Spi" (rationalize (/ x pi)))))

(defparameter pw
  (plotter :y-axis (axis :unary)
           :x-axis (axis :radians )
           :x-slot 'x :y-slot 'y :point-size 5
           :view '(:line :bar-and-point)
           (loop for x from 0 to 1 by 1/100
                 for r = (* 2 pi x)
                 collect r collect (sin r))
           (loop for x from 0 to 1 by 1/20
                 for r = (* 2 pi x)
                 collect r collect (sin r))))

;;;
;;; Example 4
;;;

(defparameter pw
  (let ((fund 110)
        (harms 16))
    (plotter :x-axis (axis :hertz :slot 'x
                           :minimum fund
                           :maximum (* fund harms))
             :y-axis (axis :normalized :slot 'y)
             :color "dark violet"
             :view ':bar-and-point
             :point-size 5
             (loop for h from 1 to harms
                   collect (* fund h)
                   collect (/ 1 h)))))

;;; looking at spectral data, genereate score from plotter data

(define log-frames
  (import-spear-data "log-drum.txt"
                     :point-format '(:keynum :amplitude)))

(plotter (loop for s in log-frames for i from 0 by 1
            append (spectrum->midi s :time i))
         :title "Logs"
         :point-height 4  :view :box
         :y-axis (axis :keynum)
         :x-axis (axis :seconds :maximum 9 :slot '(time duration)))

(events (plotter-data #&logs) "logs.mid" :channel-tuning 2)


;;; Sequencing micro-tonal MIDI data using :box view.  Musical example
;;; by Michael Klingbeil, taken from Chapter 10 of Notes from the
;;; Metalevel.

(defparameter ct9 '(t 0 8)) ;  micro-tuning first 9 channels

(defun arpeggiate-exprhy (keynums time rate midpoint-frac
                                  amplow amphi legato bass-legato
                                  bass-cutoff last-legato)
  (let* ((segs (length keynums))
         (last (1- segs))
         (midpoint (floor (* segs midpoint-frac)))
         ;; deltas below midpoint follow one curve, above another.
         (deltas (append (explsegs midpoint (* midpoint-frac time) 
                                   rate)
                         (explsegs (- segs midpoint)
                                   (* (- 1 midpoint-frac) time)
                                   (/ 1 rate)))))
    (process for i from 0
             for k in keynums
             for d in deltas
             for r = (if (< k bass-cutoff)
                       bass-legato
                       (if (= i last)
                         (* last-legato d)
                         (* legato d)))
             for a = (between 0.45 0.5)
             then (drunk a 0.1 :low amplow :high amphi )
             output (new midi :time (now)
                         :keynum k 
                         :amplitude a
                         :duration r)
             wait d)))

(defun distort-harmonics (fund distort)
  (loop for h from 1 below (floor (/ 25.0 distort)) 
        if (odds (* 0.9 distort))
        collect (keynum (* fund (expt h distort))
                        :hz t)))

(defun arpa-harmonic (note dur gap)
  ;; spawn overlapping arpeggios with mean duration of dur and mean
  ;; gap between arpeggio starts of gap seconds. each arpeggio is
  ;; upward with the general direction of arpeggio starting notes
  ;; moving downward
  (process with fund = (hertz note)
           for distort from 0.7 below 1.05 by 0.05
           for notes = (distort-harmonics fund distort)
           sprout
           (arpeggiate-exprhy notes
                              (* (vary dur 0.1) distort)
                              (between 4.0 0.25)
                              (between 0.3 0.6)
                              0.3  ; amplow
                              0.8  ; amphi
                              ; bass-legato 
                              (* dur distort 0.7)
                              2.0   ; legato 
                              59    ; bass cutoff
                              1.0)  ; last-legato 
           wait (vary gap 0.4)))

(defparameter pw
  (plotter :x-axis (axis :seconds :maximum 60
                         :labeler (lambda (x)
                                    (prin1-to-string (floor x)))
                         :slot '(time duration))
           :y-axis (axis :keynum :minimum 24 :maximum 96
                         :pixels-per-increment 96
                         :labeler (lambda (x)
                                    (format nil "~A" (note x)))
                         :slot 'keynum)
           :view :box 
           :point-height 6
           (events (arpa-harmonic 'g1 7.0 5.0) 
                   (new seq))
           (events (arpa-harmonic 'g1 7.0 5.0) 
                   (new seq))))

(events (plotter-data pw) "arpa.mid" :channel-tuning ct9)