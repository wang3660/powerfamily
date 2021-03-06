! --------------------------------------------------------------------------
! powerfamilyNET.f90: the algorithm for power family. 
! --------------------------------------------------------------------------
! This code was build upon the foundation of Yi Yang's gcdnet code.
! The author appreciated the great help from Yi Yang. 
!
!
! USAGE:
! 
! call powerfamilyNET (q, lam2, nobs, nvars, x, y, jd, pf, pf2, dfmax, &
! & pmax, nlam, flmin, ulam, eps, isd, maxit, nalam, b0, beta, ibeta, &
! & nbeta, alam, npass, jerr) 
! 
! INPUT ARGUMENTS:
! 
!    q = the parameter in power family model. 
!    lam2 = regularization parameter for the quadratic penalty of the coefficients
!    nobs = number of observations
!    nvars = number of predictor variables
!    x(nobs, nvars) = matrix of predictors, of dimension N * p; each row is an observation vector.
!    y(nobs) = response variable. This argument should be a two-level factor {-1, 1} 
!            for classification.
!    jd(jd(1)+1) = predictor variable deletion flag
!                  jd(1) = 0  => use all variables
!                  jd(1) != 0 => do not use variables jd(2)...jd(jd(1)+1)
!    pf(nvars) = relative L1 penalties for each predictor variable
!                pf(j) = 0 => jth variable unpenalized
!    pf2(nvars) = relative L2 penalties for each predictor variable
!                pf2(j) = 0 => jth variable unpenalized
!    dfmax = limit the maximum number of variables in the model.
!            (one of the stopping criterion)
!    pmax = limit the maximum number of variables ever to be nonzero. 
!           For example once beta enters the model, no matter how many 
!           times it exits or re-enters model through the path, it will 
!           be counted only once. 
!    nlam = the number of lambda values
!    flmin = user control of lambda values (>=0)
!            flmin < 1.0 => minimum lambda = flmin*(largest lambda value)
!            flmin >= 1.0 => use supplied lambda values (see below)
!    ulam(nlam) = user supplied lambda values (ignored if flmin < 1.0)
!    eps = convergence threshold for coordinate majorization descent. 
!          Each inner coordinate majorization descent loop continues 
!          until the relative change in any coefficient is less than eps.
!    isd = standarization flag:
!          isd = 0 => regression on original predictor variables
!          isd = 1 => regression on standardized predictor variables
!          Note: output solutions always reference original
!                variables locations and scales.
!    maxit = maximum number of outer-loop iterations allowed at fixed lambda value. 
!            (suggested values, maxit = 100000)
! 
! OUTPUT:
! 
!    nalam = actual number of lambda values (solutions)
!    b0(nalam) = intercept values for each solution
!    beta(pmax, nalam) = compressed coefficient values for each solution
!    ibeta(pmax) = pointers to compressed coefficients
!    nbeta(nalam) = number of compressed coefficients for each solution
!    alam(nalam) = lambda values corresponding to each solution
!    npass = actual number of passes over the data for all lambda values
!    jerr = error flag:
!           jerr  = 0 => no error
!           jerr > 0 => fatal error - no output returned
!                    jerr < 7777 => memory allocation error
!                    jerr = 7777 => all used predictors have zero variance
!                    jerr = 10000 => maxval(vp) <= 0.0
!           jerr < 0 => non fatal error - partial output:
!                    Solutions for larger lambdas (1:(k-1)) returned.
!                    jerr = -k => convergence for kth lambda value not reached
!                           after maxit (see above) iterations.
!                    jerr = -10000-k => number of non zero coefficients along path
!                           exceeds pmax (see above) at kth lambda value.
! 
! LICENSE: GNU GPL (version 2 or later)
! 
! AUTHORS:
!    Boxiang Wang (wang3660@umn.edu) and Hui Zou (hzou@stat.umn.edu), 
!    School of Statistics, University of Minnesota.
! 
! REFERENCES:
!    Yang, Y. and Zou, H. (2013). An Efficient Algorithm for Computing 
!            The HHSVM and Its Generalizations.
!    Journal of Computational and Graphical Statistics, 22, 396-415. 

      SUBROUTINE PowerfamilyNET (q, lam2, nobs, nvars, x, y, jd, &
      & pf, pf2, dfmax, pmax, nlam, flmin, ulam, eps, isd, maxit, &
      & nalam, b0, beta, ibeta, nbeta, alam, npass, jerr) 

         IMPLICIT NONE
!------- arg types ----------------------------------------------
         INTEGER :: nobs, nvars, nlam, nalam, maxit, dfmax, pmax
         INTEGER :: isd, npass, jerr, jd (*), ibeta (pmax), nbeta(nlam)
         DOUBLE PRECISION :: q, capM, lam2, flmin, eps
         DOUBLE PRECISION :: x (nobs, nvars), y (nobs)
         DOUBLE PRECISION :: pf (nvars), pf2 (nvars)
         DOUBLE PRECISION :: ulam (nlam), alam (nlam)
         DOUBLE PRECISION :: beta (pmax, nlam), b0 (nlam)

!------- local declarations -------------------------------------
         INTEGER :: j, l, nk, ierr, ju (nvars)
         DOUBLE PRECISION :: xmean (nvars), xnorm (nvars), maj (nvars)

!------- preliminary step ---------------------------------------
         CALL chkvars (nobs, nvars, x, ju)
         IF (jd(1) > 0) ju (jd(2:(jd(1)+1))) = 0
         IF (maxval(ju) <= 0) THEN
            jerr = 7777
            RETURN
         END IF
         IF (maxval(pf) <= 0.0D0) THEN
            jerr = 10000
            RETURN
         END IF
         IF (maxval(pf2) <= 0.0D0) THEN
            jerr = 10000
            RETURN
         END IF
         pf = Max (0.0D0, pf)
         pf2 = Max (0.0D0, pf2)

!------- call main function to fit models -----------------------		 
         CALL Standard (nobs, nvars, x, ju, isd, xmean, xnorm, maj)
         CALL PowerfamilyNETpath (q, lam2, maj, nobs, nvars, x, y, ju, &
         & pf, pf2, dfmax, pmax, nlam, flmin, ulam, eps, maxit, nalam, &
         & b0, beta, ibeta, nbeta, alam, npass, jerr)
         IF (jerr > 0) RETURN  ! check error after calling function

!------- organize beta afterward --------------------------------
         DO l = 1, nalam
            nk = nbeta (l)
            IF (isd == 1) THEN
               DO j = 1, nk
                  beta (j, l) = beta (j, l) / xnorm (ibeta(j))
               END DO
            END IF
            b0 (l) = b0 (l) - Dot_product (beta(1:nk, l), &
           & xmean(ibeta(1:nk)))
         END DO
         RETURN
      END SUBROUTINE PowerfamilyNET 

! ---------------------------------------------------------------
      SUBROUTINE PowerfamilyNETpath (q, lam2, maj, nobs, nvars, &
      & x, y, ju, pf, pf2, dfmax, pmax, nlam, flmin, ulam, eps, &
      & maxit, nalam, b0, beta, m, nbeta, alam, npass, jerr)
      
         IMPLICIT NONE
! ------ arg types -----------------------------------------------
         DOUBLE PRECISION, PARAMETER :: BIG = 9.9E30
         DOUBLE PRECISION, PARAMETER :: MFL = 1.0E-6
         INTEGER, PARAMETER :: MNLAM = 6
         INTEGER :: mnl, nobs, nvars, dfmax, pmax, nlam
         INTEGER :: maxit, nalam, npass, jerr 
         INTEGER :: ju (nvars), m (pmax), nbeta (nlam)
         DOUBLE PRECISION :: q
         DOUBLE PRECISION :: capM, lam2, eps
         DOUBLE PRECISION :: x (nobs, nvars), y (nobs)
         DOUBLE PRECISION :: pf (nvars), pf2 (nvars),  ulam (nlam)
         DOUBLE PRECISION :: beta (pmax, nlam), b0 (nlam)
         DOUBLE PRECISION :: alam (nlam), maj (nvars)

! ------ local declarations -------------------------------------
         DOUBLE PRECISION :: d, dif, oldb, u, v, al, alf
         DOUBLE PRECISION :: flmin, decib, fdr, dl (nobs)
         DOUBLE PRECISION :: b (0:nvars), oldbeta (0:nvars)
         DOUBLE PRECISION :: r (nobs)
         INTEGER :: i, k, j, l, vrg, ctr, ierr, ni, me
         INTEGER :: mm (nvars)

! ------ some initial setup -------------------------------------	 
         r = 0.0D0
         b = 0.0D0
         oldbeta = 0.0D0
         m = 0
         mm = 0
         npass = 0
         ni = npass
         mnl = Min (MNLAM, nlam)
         capM = 2.0D0 * (q + 1.0D0) ** 2.0D0 / q !!!
         maj = maj * capM !!!
         IF (flmin < 1.0D0) THEN
            flmin = Max (MFL, flmin)
            alf = flmin ** (1.0D0/(nlam-1.0D0))
         END IF
      
! decision boundary of loss function
         decib = q / (q + 1.0D0)
         fdr = - decib ** (q + 1.0D0)

! --------- lambda loop -----------------------------------------
         loop_lambda: DO l = 1, nlam
            IF (flmin >= 1.0D0) THEN
               al = ulam (l)
            ELSE
               IF (l > 2) THEN
                  al = al * alf
               ELSE IF (l == 1) THEN
                  al = BIG
               ELSE IF (l == 2) THEN
                  al = 0.0D0
                  DO i = 1, nobs !!!!!!!!!!!!!!!!!!!!!!
                     IF (r(i) > decib) THEN
                        dl (i) = r(i) ** (- q - 1) * fdr
                     ! recall fdr = -(q/(q+1))^(q+1)
                     ELSE
                        dl (i) = -1.0D0
                     END IF
                  END DO !!!!!!!!!!!!!!!!!!!!!!
                  DO j = 1, nvars
                     IF (ju(j) /= 0) THEN
                        IF (pf(j) > 0.0D0) THEN
                           u = Dot_product (dl * y, x(:, j))
                           al = Max (al, Abs(u) / pf(j))
                        END IF
                     END IF
                  END DO
                  al = al * alf / nobs
               END IF
            END IF
            ctr = 0
! --------- outer loop ------------------------------------------
            loop_outer: DO
               oldbeta (0) = b (0)
               IF (ni > 0) oldbeta (m(1:ni)) = b (m(1:ni))
! --------- middle loop -----------------------------------------
               loop_middle: DO
                  npass = npass + 1
                  dif = 0.0D0
! --------- 1. update beta_j first ( in middle loop) ------------
                  loop_middle_update_betaj: DO k = 1, nvars
                     IF (ju(k) /= 0) THEN
                        oldb = b (k)
                        u = 0.0D0
! Note that most literature define the margin as u, 
!    but the margin is actually r in the code.
! u: 
! \sum_{i=1}^n V'(r_i)y_i x_{ij}
                        DO i = 1, nobs   !!!!!!!!!!!!!!!!!!!!!!
                           IF (r(i) > decib) THEN
                              dl (i) = r(i) ** (- q - 1) * fdr
                           ELSE
                              dl (i) = -1.0D0
                           END IF
                           u = u + dl (i) * y (i) * x (i, k)
                        END DO !!!!!!!!!!!!!!!!!!!!!!
! u:
! M \tilde{\beta_j} - 1/n * (\sum_{i=1}^n V'(r_i)y_i x_{ij} )
                        u = maj (k) * b (k) - u / nobs
                        v = al * pf (k)
                        v = Abs (u) - v
! The update of the coefficients in Algorithm 1:
                        IF (v > 0.0D0) THEN
                           b (k) = sign (v, u) / (maj(k) + pf2(k) * lam2)
                        ELSE
                           b (k) = 0.0D0
                        END IF
                        d = b (k) - oldb
                        IF (Abs(d) > 0.0D0) THEN
                           dif = Max (dif, capM * d ** 2)  !!!
                           r = r + y * x (:, k) * d
                           IF (mm(k) == 0) THEN
                              ni = ni + 1
                              IF (ni > pmax) EXIT
                              mm (k) = ni
                              m (ni) = k !indicate which one is non-zero
                           END IF
                        END IF
                     END IF
                  END DO loop_middle_update_betaj
! --------- 2. update intercept ( in middle loop) ---------------
                  IF (ni > pmax) EXIT
                  d = 0.0D0
                  DO i = 1, nobs
                        IF (r(i) > decib) THEN
                           dl (i) = r(i) ** (- q - 1) * fdr
                        ELSE
                           dl (i) = -1.0D0
                    END IF
                    d = d + dl (i) * y (i)
                  END DO
                  d = - 1.0D0 / capM * d / nobs !!!!!!!!!
                  IF (d /= 0.0D0) THEN
! New intercept:
! newbeta0 = oldbeta0 - 1/M * \sum_{i=1}^n V'(r_i) y_i / n                  
                     b (0) = b (0) +  d
                     r = r + y * d
                     dif = Max (dif, capM * d ** 2) !!!
                  END IF
                  IF (dif < eps) EXIT
! --------- inner loop ------------------------------------------
                  loop_inner: DO
                     npass = npass + 1
                     dif = 0.0D0
! --------- 1. update beta_j first ( in inner loop) -------------
                     DO j = 1, ni
                        k = m (j)
                        oldb = b (k)
                        u = 0.0D0
                        DO i = 1, nobs   !!!!!!!!!!!!!!!!!!!!!!
                           IF (r(i) > decib) THEN
                              dl (i) = r(i) ** (- q - 1) * fdr
                           ELSE
                              dl (i) = -1.0D0
                           END IF
                           u = u + dl (i) * y (i) * x (i, k)
                        END DO !!!!!!!!!!!!!!!!!!!!!!
                        u = maj (k) * b (k) - u / nobs
                        v = al * pf (k)
                        v = Abs (u) - v
                        IF (v > 0.0D0) THEN
                           b (k) = sign (v, u) / (maj(k) + pf2(k) * lam2)
                        ELSE
                           b (k) = 0.0D0
                        END IF
                        d = b (k) - oldb
                        IF (Abs(d) > 0.0D0) THEN
                           dif = Max (dif, capM * d ** 2) !!!
                           r = r + y * x (:, k) * d
                        END IF
                     END DO
! --------- 2. update intercept ( in inner loop) ----------------
                     d = 0.0D0
                        DO i = 1, nobs   !!!!!!!!!!!!!!!!!!!!!!
                           IF (r(i) > decib) THEN
                              dl (i) = r(i) ** (- q - 1) * fdr
                           ELSE
                              dl (i) = -1.0D0
                           END IF
                        d = d + dl (i) * y (i)
                     END DO !!!!!!!!!!!!!!!!!!!!!!
                     d = - 1.0D0 / capM * d / nobs !!!!!!!!!
                     IF (d /= 0.0D0) THEN
                        b (0) = b (0) + d
                        r = r + y * d
                        dif = Max (dif, capM * d ** 2) !!!
                     END IF
                     IF (dif < eps) EXIT
                  END DO loop_inner
               END DO loop_middle
               IF (ni > pmax) EXIT
! --------- final check -----------------------------------------
               vrg = 1
               IF ((b(0)-oldbeta(0))**2 >= eps) vrg = 0
               DO j = 1, ni
                  IF ((b(m(j))-oldbeta(m(j)))**2 >= eps) THEN
                     vrg = 0
                     EXIT
                  END IF
               END DO
               IF (vrg == 1) EXIT
               ctr = ctr + 1
               IF (ctr > maxit) THEN
                  jerr = - l
                  RETURN
               END IF
            END DO loop_outer
! --------- final update variable save results ------------------
            IF (ni > pmax) THEN
               jerr = - 10000 - l
               EXIT
            END IF
            IF (ni > 0) beta (1:ni, l) = b (m(1:ni))
            nbeta (l) = ni
            b0 (l) = b (0)
            alam (l) = al
            nalam = l
            IF (l < mnl) CYCLE
            IF (flmin >= 1.0D0) CYCLE
            me = count (beta(1:ni, l) /= 0.0D0)
            IF (me > dfmax) EXIT
         END DO loop_lambda
         RETURN
      END SUBROUTINE PowerfamilyNETpath

