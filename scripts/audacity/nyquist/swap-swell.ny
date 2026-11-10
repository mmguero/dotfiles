;nyquist plug-in
;version 4
;type process
;name "Swap Swell"
;author "Seth"

(let ((f (min 0.5 (/ 0.075 (get-duration 1)))))
  (mult *track* (pwlv 0 f 1 (- 1 f) 1 1 0)))
