module eos_table
  use kinds
  implicit none
  type :: EOSTable
     integer :: nr=0, nt=0
     real(rk), allocatable :: rho(:), temp(:)
     real(rk), allocatable :: P(:,:), Cv(:,:)   ! (nr, nt)
  end type
contains
  subroutine read_eos_csv(path, tbl, ios)
    character(len=*), intent(in) :: path
    type(EOSTable),   intent(inout) :: tbl
    integer,          intent(out) :: ios
    integer :: iu, i, j, nr, nt
    character(len=512) :: line
    ios = 0
    open(newunit=iu, file=path, status='old', action='read', iostat=ios)
    if (ios/=0) return
    ! read NR NT from first non-comment, non-blank line
    do
      read(iu,'(A)', iostat=ios) line
      if (ios/=0) then
        close(iu); return
      end if
      if (len_trim(line)==0) cycle
      if (line(1:1) == '#') cycle
      read(line,*, iostat=ios) nr, nt
      if (ios==0) exit
    end do
    allocate(tbl%rho(nr), tbl%temp(nt), tbl%P(nr,nt), tbl%Cv(nr,nt))
    ! read NR rho values
    i = 0
    do while (i < nr)
      read(iu,'(A)', iostat=ios) line
      if (ios/=0) then
        close(iu); ios= -1; return
      end if
      if (len_trim(line)==0) cycle
      if (line(1:1) == '#') cycle
      i = i + 1
      read(line,*, iostat=ios) tbl%rho(i)
      if (ios/=0) then
        close(iu); return
      end if
    end do
    ! read NT temp values
    j = 0
    do while (j < nt)
      read(iu,'(A)', iostat=ios) line
      if (ios/=0) then
        close(iu); ios = -2; return
      end if
      if (len_trim(line)==0) cycle
      if (line(1:1) == '#') cycle
      j = j + 1
      read(line,*, iostat=ios) tbl%temp(j)
      if (ios/=0) then
        close(iu); return
      end if
    end do
    ! read NR rows of P
    i = 0
    do while (i < nr)
      read(iu,'(A)', iostat=ios) line
      if (ios/=0) then
        close(iu); ios = -3; return
      end if
      if (len_trim(line)==0) cycle
      if (line(1:1) == '#') cycle
      i = i + 1
      read(line,*, iostat=ios) tbl%P(i,1:nt)
      if (ios/=0) then
        close(iu); return
      end if
    end do
    ! read NR rows of Cv
    i = 0
    do while (i < nr)
      read(iu,'(A)', iostat=ios) line
      if (ios/=0) then
        close(iu); ios = -4; return
      end if
      if (len_trim(line)==0) cycle
      if (line(1:1) == '#') cycle
      i = i + 1
      read(line,*, iostat=ios) tbl%Cv(i,1:nt)
      if (ios/=0) then
        close(iu); return
      end if
    end do
    close(iu)
  end subroutine

  subroutine eos_lookup(tbl, rho, T, P, Cv)
    type(EOSTable), intent(in) :: tbl
    real(rk), intent(in) :: rho, T
    real(rk), intent(out):: P, Cv
    integer :: i, j
    real(rk) :: fr, ft
    i = max(1, min(tbl%nr-1, count(tbl%rho <= rho)))
    j = max(1, min(tbl%nt-1, count(tbl%temp <= T)))
    fr = 0._rk; if (tbl%rho(i+1)>tbl%rho(i)) fr = (rho - tbl%rho(i)) / (tbl%rho(i+1)-tbl%rho(i))
    ft = 0._rk; if (tbl%temp(j+1)>tbl%temp(j)) ft = (T - tbl%temp(j)) / (tbl%temp(j+1)-tbl%temp(j))
    P  = (1-fr)*(1-ft)*tbl%P(i,j) + fr*(1-ft)*tbl%P(i+1,j) + (1-fr)*ft*tbl%P(i,j+1) + fr*ft*tbl%P(i+1,j+1)
    Cv = (1-fr)*(1-ft)*tbl%Cv(i,j)+ fr*(1-ft)*tbl%Cv(i+1,j)+ (1-fr)*ft*tbl%Cv(i,j+1)+ fr*ft*tbl%Cv(i+1,j+1)
  end subroutine
end module eos_table
