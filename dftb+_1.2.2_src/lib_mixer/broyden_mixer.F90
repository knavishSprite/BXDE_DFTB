!!* Contains a modified Broyden mixer.
!!* @desc
!!*   The modified Broyden mixer implemented here is practicaly the same as
!!*   the one in the old DFTB code. A detailed description of the method can
!!*   be found in Johnson's paper.
!!* @see D.D. Johnson, PRB 38, 12807 (1988)
!!* @note In order to use the mixer you have to create and reset it.
module BroydenMixer
# include "allocate.h"
# include "assert.h"  
  use accuracy
  use message
  use Fifo
  implicit none
  
  private

  !!* Contains the necessary data for a Broyden mixer.
  type OBroydenMixer
    private
    integer :: iIter                       !!* Actual iteration
    integer :: mIter                       !!* Nr. of maximal iterations
    integer :: nElem                       !!* Nr. of element in the vectors
    real(dp) :: omega0                     !!* Jacobi matrix differences
    real(dp) :: alpha                      !!* Mixing parameter
    real(dp) :: minWeight                  !!* Minimal weight
    real(dp) :: maxWeight                  !!* Maximal weight
    real(dp) :: weightFac                  !!* Weighting factor (numerator)
    real(dp), pointer :: ww(:)             !!* Weights for prev. iterations
    real(dp), pointer :: qDiffLast(:)      !!* Charge difference in last iter.
    real(dp), pointer :: qInpLast(:)       !!* Input charge in last iteration
    real(dp), pointer :: aa(:,:)           !!* Storage for the "a" matrix
    type(OFifoRealR1), pointer :: fifoDF   !!* Fifo for prev. DF vectors
    type(OFifoRealR1), pointer :: fifoUU   !!* Previous U vectors.
  end type OBroydenMixer


  !!* Creates Broyden mixer
  interface create
    module procedure BroydenMixer_create
  end interface

  !!* Destroys Broyden mixer
  interface destroy
    module procedure BroydenMixer_destroy
  end interface

  !!* Resets Broyden mixer
  interface reset
    module procedure BroydenMixer_reset
  end interface

  !!* Does the charge mixing
  interface mix
    module procedure BroydenMixer_mix
  end interface

  public :: OBroydenMixer
  public :: create, destroy, reset, mix


  character(*), parameter :: tmpPrefix1 = "tmp-broyden1."   !* Temp. file name
  character(*), parameter :: tmpPrefix2 = "tmp-broyden2."   !* Temp. file name
    

contains

  !!* Creates a Broyden mixer instance.
  !!* @param self      Pointer to an initialized Broyden mixer on exit
  !!* @param mIter     Maximal nr. of iterations (max. nr. of vectors to store)
  !!* @param mixParam  Mixing parameter
  !!* @param omega0    Weight for the Jacobi matrix differences
  !!* @param minWeight Minimal weigth allowed
  !!* @param maxWeight Maximal weigth allowed
  !!* @param weightFac Nominator of the weight
  !!* @param nKeep     Nr. of generations to keep in memory (instead on disc)
  !!* @desc
  !!*   The weigth associated with an iteration is calculated as weigthFac/ww
  !!*   where ww is the Euclidian norm of the charge difference vector. If
  !!*   the calculated weigth is outside of the [minWeight,maxWeight] region
  !!*   it is replaced with the appropriate boundary value.
  subroutine BroydenMixer_create(self, mIter, mixParam, omega0, minWeight, &
      &maxWeight, weightFac, nKeep)
    type(OBroydenMixer), pointer :: self
    integer, intent(in) :: mIter
    real(dp), intent(in) :: mixParam
    real(dp), intent(in) :: omega0
    real(dp), intent(in) :: minWeight
    real(dp), intent(in) :: maxWeight
    real(dp), intent(in) :: weightFac
    integer, intent(in) :: nKeep
    
    ASSERT(mIter > 0)
    ASSERT(mixParam > 0.0_dp)
    ASSERT(omega0 > 0.0_dp)
    ASSERT(nKeep >= 0)

    INITALLOCATE_P(self)
    self%nElem = 0
    self%mIter = mIter
    self%alpha = mixParam
    self%omega0 = omega0
    self%minWeight = minWeight
    self%maxWeight = maxWeight
    self%weightFac = weightFac
    INITALLOCATE_P(self%fifoDF)
    INITALLOCATE_P(self%fifoUU)
    call init(self%fifoDF, nKeep, tmpPrefix1)
    call init(self%fifoUU, nKeep, tmpPrefix2)

    INITALLOCATE_PARR(self%ww, (mIter-1))
    INITALLOCATE_PARR(self%qInpLast, (self%nElem))
    INITALLOCATE_PARR(self%qDiffLast, (self%nElem))
    INITALLOCATE_PARR(self%aa, (mIter-1, mIter-1))
    
  end subroutine BroydenMixer_create



  !!* Makes the mixer ready for a new SCC cycle
  !!* @param self  Broyden mixer instance
  !!* @param nElem Length of the vectors to mix
  subroutine BroydenMixer_reset(self, nElem)
    type(OBroydenMixer), pointer :: self
    integer, intent(in) :: nElem

    ASSERT(nElem > 0)

    if (nElem /= self%nElem) then
      self%nElem = nElem
      DEALLOCATE_PARR(self%qInpLast)
      DEALLOCATE_PARR(self%qDiffLast)
      ALLOCATE_PARR(self%qInpLast, (self%nElem))
      ALLOCATE_PARR(self%qDiffLast, (self%nElem))
    end if
    self%iIter = 0
    self%ww(:) = 0.0_dp
    self%aa(:,:) = 0.0_dp
    call reset(self%fifoDF, nElem)
    call reset(self%fifoUU, nElem)

  end subroutine BroydenMixer_reset



  !!* Destroys the Broyden mixer
  !!* @param self Broyden mixer instance.
  subroutine BroydenMixer_destroy(self)
    type(OBroydenMixer), pointer :: self

    if (associated(self)) then
      call destruct(self%fifoDF)
      call destruct(self%fifoUU)
      DEALLOCATE_P(self%fifoDF)
      DEALLOCATE_P(self%fifoUU)
      DEALLOCATE_PARR(self%ww)
      DEALLOCATE_PARR(self%qDiffLast)
      DEALLOCATE_PARR(self%qInpLast)
      DEALLOCATE_PARR(self%aa)
    end if
    DEALLOCATE_P(self)
    
  end subroutine BroydenMixer_destroy

  

  !!* Mixes charges according to the modified Broyden method
  !!* @param self       Pointer to the Broyden mixer
  !!* @param qInpResult Input charges on entry, mixed charges on exit.
  !!* @param qDiff      Charge difference
  subroutine BroydenMixer_mix(self, qInpResult, qDiff)
    type(OBroydenMixer), pointer :: self
    real(dp), intent(inout) :: qInpResult(:)
    real(dp), intent(in)    :: qDiff(:)

    self%iIter = self%iIter + 1
    if (self%iIter > self%mIter) then
      call error("Broyden mixer: Maximal nr. of steps exceeded")
    end if
    call modifiedBroydenMixing(qInpResult, self%qInpLast, self%qDiffLast, &
        &self%aa, self%ww, self%iIter, qDiff, self%alpha, self%omega0, &
        &self%minWeight, self%maxWeight, self%weightFac, self%nElem, &
        &self%fifoDF, self%fifoUU)

  end subroutine BroydenMixer_mix



  !!* Does the real work for the Broyden mixer
  !!* @param qInpResult Current input charge on entry, mixed charged on exit
  !!* @param qInpLast   Input charge vector of the previous iterations
  !!* @param qDiffLast  Charge difference of the previous iteration
  !!* @param aa         The matrix a (needed for the mixing).
  !!* @param ww         Weighting factors of the iterations.
  !!* @param nn         Current iteration number
  !!* @param qDiff      Charge difference of the current iteration.
  !!* @param alpha      Mixing parameter
  !!* @param omega0     Parameter omega0.
  !!* @param nElem      Nr. of elements in the vectors
  !!* @param fifoDF     Rank one real FIFO instance containing prev. DFs
  !!* @param fifoUU     Rank one real FIFO instance containing prev. U vectors
  subroutine modifiedBroydenMixing(qInpResult, qInpLast, qDiffLast, aa, ww, &
      &nn, qDiff, alpha, omega0, minWeight, maxWeight, weightFac, nElem, &
      &fifoDF, fifoUU)
    use LapackRoutines, only: matinv
    real(dp), intent(inout) :: qInpResult(:)
    real(dp), intent(inout) :: qInpLast(:)
    real(dp), intent(inout) :: qDiffLast(:)
    real(dp), intent(inout) :: aa(:,:)
    real(dp), intent(inout) :: ww(:)
    integer, intent(in) :: nn
    real(dp), intent(in) :: qDiff(:)
    real(dp), intent(in) :: alpha
    real(dp), intent(in) :: omega0
    real(dp), intent(in) :: minWeight
    real(dp), intent(in) :: maxWeight
    real(dp), intent(in) :: weightFac
    integer, intent(in) :: nElem
    type(OFifoRealR1), pointer :: fifoDF
    type(OFifoRealR1), pointer :: fifoUU

    real(dp), allocatable :: beta(:,:), cc(:,:), gamma(:,:)
    real(dp), allocatable :: dF_uu(:)      !! Current DF or U-vector
    real(dp), allocatable :: buffer(:)     !! One of the prev. DF or U -s
    real(dp) :: invNorm
    integer :: nn_1
    integer :: ii

    nn_1 = nn - 1

    ASSERT(nn > 0)
    ASSERT(size(qInpResult) == nElem)
    ASSERT(size(qInpLast) == nElem)
    ASSERT(size(qDiffLast) == nElem)
    ASSERT(size(qDiff) == nElem)
    ASSERT(all(shape(aa) >= (/ nn_1, nn_1 /)))
    ASSERT(size(ww) >= nn_1)

    !! First iteration: simple mix and storage of qInp and qDiff
    if (nn == 1) then
      qInpLast(:) = qInpResult(:)
      qDiffLast(:) = qDiff(:)
      qInpResult(:) = qInpResult(:) + alpha * qDiff(:)
      return
    end if

    ALLOCATE_(beta, (nn_1, nn_1))
    ALLOCATE_(cc, (1, nn_1))
    ALLOCATE_(gamma, (1, nn_1))
    ALLOCATE_(dF_uu, (nElem))
    ALLOCATE_(buffer, (nElem))

    !! Create weight factor omega for current iteration
    ww(nn_1) = sqrt(dot_product(qDiff, qDiff))
    if (ww(nn_1) > weightFac / maxWeight) then
      ww(nn_1) = weightFac / ww(nn_1)
    else
      ww(nn_1) = maxWeight
    end if
    if (ww(nn_1) < minWeight) then
      ww(nn_1) = minWeight
    end if
    
    !! Build |DF(m-1)> and  (m is the current iteration number)
    dF_uu(:) = qDiff(:) - qDiffLast(:)
    invNorm = 1.0_dp / sqrt(dot_product(dF_uu, dF_uu))
    dF_uu(:) = invNorm * dF_uu(:)

    !! Build a, beta, c, and gamma
    do ii = 1, nn - 2
      call get(fifoDF, buffer)
      aa(ii, nn_1) = dot_product(buffer, dF_uu)
      aa(nn_1, ii) = aa(ii, nn_1)
      cc(1, ii) = ww(ii) * dot_product(buffer, qDiff)
    end do
    aa(nn_1, nn_1) = 1.0_dp
    cc(1, nn_1) = ww(nn_1) * dot_product(dF_uu, qDiff)

    do ii = 1, nn_1
      beta(:nn-1, ii) = ww(:nn-1) * ww(ii) * aa(:nn-1,ii)
      beta(ii, ii) = beta(ii, ii) + omega0**2
    end do
    call matinv(beta)
    
    gamma = matmul(cc, beta)

    !! Store |dF(m-1)>
    call push(fifoDF, dF_uu)

    !! Create |u(m-1)>
    dF_uu(:) = alpha * dF_uu(:) + invNorm * (qInpResult(:) - qInpLast(:))

    !! Save charge vectors before overwriting
    qInpLast(:) = qInpResult(:)
    qDiffLast(:) = qDiff(:)

    !! Build new vector
    qInpResult(:) = qInpResult + alpha * qDiff(:)
    do ii = 1, nn-2
      call get(fifoUU, buffer)
      qInpResult(:) = qInpResult(:) - ww(ii) * gamma(1,ii) * buffer(:)
    end do
    qInpResult(:) = qInpResult(:) - ww(nn_1) * gamma(1,nn_1) * dF_uu(:)

    !! Save |u(m-1)> and |dF(m-1)>
    call push(fifoUU, dF_uu)

    DEALLOCATE_(beta)
    DEALLOCATE_(cc)
    DEALLOCATE_(gamma)
    DEALLOCATE_(dF_uu)
    DEALLOCATE_(buffer)

  end subroutine modifiedBroydenMixing

  
end module BroydenMixer
