;nyquist plug-in
;version 4
;type process
;name "Swap Dip"
;author "Seth"

(let ((f (min 0.5 (/ 0.075 (get-duration 1)))))
  (mult *track* (pwlv 1 f 0 (- 1 f) 0 1 1)))
