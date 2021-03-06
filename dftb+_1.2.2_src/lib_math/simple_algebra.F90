!!* Simple algebraic stuff for simple cases, where LAPACK would be an overkill
module SimpleAlgebra
#include "assert.h"
  use accuracy
  implicit none
  private

  public :: cross3, determinant33, derivDeterminant33, invert33

contains

  !!* Cross product. (Only temporary!)
  !!* @param res  Resulting vector.
  !!* @param v1   First vector.
  !!* @param v2   Second vector.
  subroutine cross3(res, v1, v2)
    real(dp), intent(out) :: res(3)
    real(dp), intent(in)  :: v1(3)
    real(dp), intent(in)  :: v2(3)

    res(1) = v1(2) * v2(3) - v1(3) * v2(2)
    res(2) = v1(3) * v2(1) - v1(1) * v2(3)
    res(3) = v1(1) * v2(2) - v1(2) * v2(1)

  end subroutine cross3



  !!* Determinant of a 3x3 matrix (Only temporary!)
  !!* @param matrix The matrix for which to calculate the determinant.
  !!* @return       Determinant of the matrix.
  real(dp) function  determinant33(matrix)
    real(dp), intent(in) :: matrix(:, :)

    real(dp) :: tmp

    ASSERT(all(shape(matrix) == (/3, 3/)))

    tmp = matrix(1, 1) &
        &* (matrix(2, 2) * matrix(3, 3) - matrix(3, 2) * matrix(2, 3))
    tmp = tmp - matrix(1, 2) &
        &* (matrix(2, 1) * matrix(3, 3) - matrix(3, 1) * matrix(2, 3))
    tmp = tmp + matrix(1, 3) &
        &* (matrix(2, 1) * matrix(3, 2) - matrix(3, 1) * matrix(2, 2))

    determinant33 = abs(tmp)

  end function determinant33

  !!* Derivative of determinant of a 3x3 matrix (Only temporary!)
  !!* @param deriv  derivative of the determinant
  !!* @param matrix The matrix from which to calculate the determinant.
  subroutine  derivDeterminant33(deriv,matrix)
    real(dp), intent(out) :: deriv(3, 3)
    real(dp), intent(in)  :: matrix(3, 3)
    
    deriv(1,1) = matrix(2, 2) * matrix(3, 3) - matrix(3, 2) * matrix(2, 3)
    deriv(1,2) = matrix(2, 3) * matrix(3, 1) - matrix(3, 3) * matrix(2, 1)
    deriv(1,3) = matrix(2, 1) * matrix(3, 2) - matrix(3, 1) * matrix(2, 2)
    deriv(2,1) = matrix(1, 3) * matrix(3, 2) - matrix(1, 2) * matrix(3, 3)
    deriv(2,2) = matrix(1, 1) * matrix(3, 3) - matrix(1, 3) * matrix(3, 1)
    deriv(2,3) = matrix(1, 2) * matrix(3, 1) - matrix(1, 1) * matrix(3, 2)
    deriv(3,1) = matrix(1, 2) * matrix(2, 3) - matrix(1, 3) * matrix(2, 2)
    deriv(3,2) = matrix(1, 3) * matrix(2, 1) - matrix(1, 1) * matrix(2, 3)
    deriv(3,3) = matrix(1, 1) * matrix(2, 2) - matrix(1, 2) * matrix(2, 1)
    
!    deriv = abs(deriv)
    deriv = deriv * sign(1.0_dp,determinant33(matrix))
    
  end subroutine derivDeterminant33



  !!* Inverts a 3x3 matrix (Only temporary!)
  !!* @param inverted Contains the inverted matrix on return.
  !!* @param orig     Matrix to invert.
  !!* @param optDet   Determinant of the matrix, if already known.
  subroutine invert33(inverted, orig, optDet)
    real(dp), intent(out)          :: inverted(:, :)
    real(dp), intent(in)           :: orig(:, :)
    real(dp), intent(in), optional :: optDet

    real(dp) :: det

    ASSERT(all(shape(inverted) == (/3, 3/)))
    ASSERT(all(shape(orig) == (/3, 3/)))

    if (present(optDet)) then
      det = optDet
    else
      det = determinant33(orig)
    end if

    inverted(1, 1) = -orig(2, 3) * orig(3, 2) + orig(2, 2) * orig(3, 3)
    inverted(2, 1) =  orig(2, 3) * orig(3, 1) - orig(2, 1) * orig(3, 3)
    inverted(3, 1) = -orig(2, 2) * orig(3, 1) + orig(2, 1) * orig(3, 2)

    inverted(1, 2) =  orig(1, 3) * orig(3, 2) - orig(1, 2) * orig(3, 3)
    inverted(2, 2) = -orig(1, 3) * orig(3, 1) + orig(1, 1) * orig(3, 3)
    inverted(3, 2) =  orig(1, 2) * orig(3, 1) - orig(1, 1) * orig(3, 2)

    inverted(1, 3) = -orig(1, 3) * orig(2, 2) + orig(1, 2) * orig(2, 3)
    inverted(2, 3) =  orig(1, 3) * orig(2, 1) - orig(1, 1) * orig(2, 3)
    inverted(3, 3) = -orig(1, 2) * orig(2, 1) + orig(1, 1) * orig(2, 2)
    inverted = inverted / det

  end subroutine invert33

end module SimpleAlgebra
