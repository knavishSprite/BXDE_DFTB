!!* Contains routines relating to evaluating factorials
!!* @todo checks for the range of factorials that do not break real/int data
!!* types for different machines
module factorial
  
  use accuracy, only : dp
  
  implicit none

  !!* Calculate factorals up to a given order
  !!* @param nbang factorials
  !!* @param n calculate factorials from 0 to n 
  interface fact
     module procedure int_fact
     module procedure real_fact
  end interface fact
  
contains
  
  subroutine int_fact(nbang,n)
#include "assert.h"
    implicit none
    integer, intent(inout) :: nbang(0:)
    integer, intent(in) :: n
    integer i
    ASSERT(n >= 0)
    ASSERT(size(nbang)==n+1)
    nbang(0)=1
    do i=1,n
       nbang(i)=nbang(i-1)*i
    end do
  end subroutine int_fact

  subroutine real_fact(nbang,n)
#include "assert.h"
    use accuracy, only : dp
    implicit none
    real(dp), intent(inout) :: nbang(0:)
    integer, intent(in) :: n
    integer i
    ASSERT(n >= 0)
    ASSERT(size(nbang)==n+1)
    nbang(0)=1.0_dp
    do i=1,n
       nbang(i)=nbang(i-1)*real(i,dp)
    end do
  end subroutine real_fact

end module factorial
