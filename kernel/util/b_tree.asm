;;======================================================================================================================
;;///// b_tree.asm ///////////////////////////////////////////////////////////////////////////////////////// GPLv2 /////
;;======================================================================================================================
;; (c) 2011 Ostin project <http://ostin.googlecode.com/>
;;======================================================================================================================
;; This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public
;; License as published by the Free Software Foundation, either version 2 of the License, or (at your option) any later
;; version.
;;
;; This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied
;; warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License along with this program. If not, see
;; <http://www.gnu.org/licenses/>.
;;======================================================================================================================

;-----------------------------------------------------------------------------------------------------------------------
kproc util.b_tree.find ;////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> eax ^= data to find (passed as first argument to callback)
;> ebx ^= root node
;> ecx ^= comparator callback, f(eax, ebx)
;-----------------------------------------------------------------------------------------------------------------------
;< eax ^= actual node
;-----------------------------------------------------------------------------------------------------------------------
        klog_   LOG_TRACE, "util.b_tree.find(%x,%x,%x)\n", eax, ebx, ecx
        push    ebx

  .next_node:
        test    ebx, ebx
        jz      .error

        lea     edx, [ebx + rb_tree_node_t._.left_ptr]

        call    ecx
        je      .exit
        jb      @f

        lea     edx, [ebx + rb_tree_node_t._.right_ptr]

    @@: mov     ebx, [edx]
        jmp     .next_node

  .exit:
        xchg    eax, ebx
        pop     ebx
        ret

  .error:
        xor     eax, eax
        pop     ebx
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc util.b_tree.enumerate ;///////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> ebx ^= root node
;> ecx ^= callback, f(eax)
;-----------------------------------------------------------------------------------------------------------------------
;< eax ^= 0 (completed) or not 0 (interrupted)
;-----------------------------------------------------------------------------------------------------------------------
        klog_   LOG_TRACE, "util.b_tree.enumerate(%x, %x)\n", ebx, ecx

        xor     eax, eax
        test    ebx, ebx
        jz      .exit

        push    ebx
        mov     ebx, [ebx + rb_tree_node_t._.left_ptr]
        call    util.b_tree.enumerate
        test    eax, eax
        pop     ebx
        jnz     .exit

        mov     eax, ebx
        call    ecx
        test    eax, eax
        jnz     .exit

        mov     ebx, [ebx + rb_tree_node_t._.right_ptr]
        jmp     util.b_tree.enumerate ; tail recursion here

  .exit:
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc util.rb_tree.insert ;/////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> eax ^= node to insert
;> ebx ^= root node
;> ecx ^= comparator callback, f(eax, ebx)
;-----------------------------------------------------------------------------------------------------------------------
;< eax ^= new root node
;-----------------------------------------------------------------------------------------------------------------------
        klog_   LOG_TRACE, "util.b_tree.insert(%x,%x,%x)\n", eax, ebx, ecx
        and     [eax + rb_tree_node_t._.parent_ptr], 0
        and     [eax + rb_tree_node_t._.left_ptr], 0
        and     [eax + rb_tree_node_t._.right_ptr], 0
        or      [eax + rb_tree_node_t._.color], 1

        test    ebx, ebx
        jz      .case_1

  .next_node:
        lea     edx, [ebx + rb_tree_node_t._.left_ptr]

        call    ecx
        je      .error
        jb      @f

        lea     edx, [ebx + rb_tree_node_t._.right_ptr]

    @@: cmp     dword[edx], 0
        je      @f

        mov     ebx, [edx]
        jmp     .next_node

    @@: mov     [edx], eax
        mov     [eax + rb_tree_node_t._.parent_ptr], ebx

  .case_1:
        ;klog_   LOG_DEBUG, "  case 1\n"
        ; eax ^= node
        mov     edx, [eax + rb_tree_node_t._.parent_ptr]
        test    edx, edx
        jnz     .case_2

        and     [eax + rb_tree_node_t._.color], 0
        jmp     .exit

  .case_2:
        ;klog_   LOG_DEBUG, "  case 2\n"
        ; eax ^= node
        ; edx ^= parent node
        cmp     [edx + rb_tree_node_t._.color], 0
        je      .exit

  .case_3:
        ;klog_   LOG_DEBUG, "  case 3\n"
        ; eax ^= node
        ; edx ^= parent node
        push    eax

        call    util.b_tree._.get_uncle
        test    eax, eax
        jz      .case_4

        cmp     [eax + rb_tree_node_t._.color], 0
        je      .case_4

        and     [edx + rb_tree_node_t._.color], 0
        and     [eax + rb_tree_node_t._.color], 0

        mov     eax, ecx
        or      [eax + rb_tree_node_t._.color], 1
        add     esp, 4
        jmp     .case_1 ; tail recursion here

  .case_4:
        ;klog_   LOG_DEBUG, "  case 4\n"
        ; [esp] ^= node
        ; edx ^= parent node
        ; ecx ^= grandparent node
        pop     eax
        xchg    eax, ecx

        cmp     ecx, [edx + rb_tree_node_t._.right_ptr]
        jne     .case_4_check_other
        cmp     edx, [eax + rb_tree_node_t._.left_ptr]
        jne     .case_4_check_other

        mov     eax, edx
        call    util.b_tree._.rotate_left
        mov     eax, [ecx + rb_tree_node_t._.left_ptr]
        jmp     .case_5

  .case_4_check_other:
        cmp     ecx, [edx + rb_tree_node_t._.left_ptr]
        jne     .case_4_end
        cmp     edx, [eax + rb_tree_node_t._.right_ptr]
        jne     .case_4_end

        mov     eax, edx
        call    util.b_tree._.rotate_right
        mov     eax, [ecx + rb_tree_node_t._.right_ptr]
        jmp     .case_5

  .case_4_end:
        mov     eax, ecx

  .case_5:
        ;klog_   LOG_DEBUG, "  case 5\n"
        ; eax ^= node
        mov     ecx, eax
        mov     edx, [eax + rb_tree_node_t._.parent_ptr]

        call    util.b_tree._.get_grandparent

        and     [edx + rb_tree_node_t._.color], 0
        or      [eax + rb_tree_node_t._.color], 1

        cmp     ecx, [edx + rb_tree_node_t._.left_ptr]
        jne     .case_5_check_other
        cmp     edx, [eax + rb_tree_node_t._.left_ptr]
        jne     .case_5_check_other

        call    util.b_tree._.rotate_right
        jmp     .case_5_end

  .case_5_check_other:
        cmp     ecx, [edx + rb_tree_node_t._.right_ptr]
        jne     .case_5_end
        cmp     edx, [eax + rb_tree_node_t._.right_ptr]
        jne     .case_5_end

        call    util.b_tree._.rotate_left

  .case_5_end:
        mov     eax, ecx

  .exit:
        jmp     util.b_tree._.get_root

  .error:
        xor     eax, eax
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc util.rb_tree.remove ;/////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> eax ^= node to remove
;-----------------------------------------------------------------------------------------------------------------------
;< eax ^= new root node
;-----------------------------------------------------------------------------------------------------------------------
        klog_   LOG_TRACE, "util.b_tree.remove(%x)\n", eax
        mov     ecx, [eax + rb_tree_node_t._.left_ptr]
        mov     ebx, [eax + rb_tree_node_t._.right_ptr]

        test    ecx, ecx
        jz      .delete
        xchg    ebx, ecx
        test    ecx, ecx
        jz      .delete

    @@: ; ecx ^= right child
        mov     ebx, [ecx + rb_tree_node_t._.left_ptr]
        test    ebx, ebx
        jz      @f

        xchg    ebx, ecx
        jmp     @b

    @@: ; ecx ^= smallest-valued node in right subtree
        xchg    ebx, ecx
        call    util.b_tree._.swap
        xchg    eax, ebx
        mov     ebx, [eax + rb_tree_node_t._.right_ptr]

  .delete:
        ;klog_   LOG_DEBUG, "  delete\n"
        ; eax ^= node
        ; ebx ^= [presumably] non-null child node (while its sibling is null node for sure)
        cmp     [eax + rb_tree_node_t._.color], 0
        jne     .replace

        xor     ecx, ecx
        test    ebx, ebx
        jz      @f

        mov     cl, [ebx + rb_tree_node_t._.color]

    @@: mov     [eax + rb_tree_node_t._.color], cl

        push    eax ebx
        call    .case_1
        pop     ebx eax

  .replace:
        ; eax ^= node
        ; ebx ^= non-null child node
        test    ebx, ebx
        jnz     @f

        ;klog_   LOG_DEBUG, "  replace (null)\n"
        mov     ecx, [eax + rb_tree_node_t._.parent_ptr]
        and     [eax + rb_tree_node_t._.parent_ptr], 0
        call    util.b_tree._.fix_parent_pointer
        xchg    eax, ecx
        jmp     .fix_root_color

    @@: ;klog_   LOG_DEBUG, "  replace\n"
        call    util.b_tree._.replace
        xchg    eax, ebx

  .fix_root_color:
        call    util.b_tree._.get_root
        test    eax, eax
        jz      .exit

        and     [eax + rb_tree_node_t._.color], 0
        jmp     .exit

  .case_1:
        ;klog_   LOG_DEBUG, "  case 1\n"
        ; eax ^= node
        mov     ebx, [eax + rb_tree_node_t._.parent_ptr]
        test    ebx, ebx
        jz      .exit

  .case_2:
        ;klog_   LOG_DEBUG, "  case 2\n"
        ; eax ^= node
        ; ebx ^= parent node
        push    eax

        call    util.b_tree._.get_sibling

        test    eax, eax
        jz      .case_3
        cmp     [eax + rb_tree_node_t._.color], 0
        je      .case_3

        or      [ebx + rb_tree_node_t._.color], 1
        and     [eax + rb_tree_node_t._.color], 0

        mov     eax, [ebx + rb_tree_node_t._.left_ptr]
        cmp     eax, [esp]
        mov     eax, ebx
        jne     @f

        call    util.b_tree._.rotate_left
        jmp     .case_3

    @@: call    util.b_tree._.rotate_right

  .case_3:
        ;klog_   LOG_DEBUG, "  case 3\n"
        ; [esp] ^= node
        mov     eax, [esp]

        mov     ebx, [eax + rb_tree_node_t._.parent_ptr]
        call    util.b_tree._.get_sibling

        test    ebx, ebx
        jz      @f
        cmp     [ebx + rb_tree_node_t._.color], 0
        jne     .case_4

    @@: test    eax, eax
        jz      .case_4 ; case_3_exit
        cmp     [eax + rb_tree_node_t._.color], 0
        jne     .case_4

        mov     ecx, [eax + rb_tree_node_t._.left_ptr]
        test    ecx, ecx
        jz      @f
        cmp     [ecx + rb_tree_node_t._.color], 0
        jne     .case_4

    @@: mov     ecx, [eax + rb_tree_node_t._.right_ptr]
        test    ecx, ecx
        jz      .case_3_exit
        cmp     [ecx + rb_tree_node_t._.color], 0
        jne     .case_4

  .case_3_exit:
        or      [eax + rb_tree_node_t._.color], 1
        xchg    eax, ebx
        add     esp, 4
        jmp     .case_1 ; tail recursion here

  .case_4:
        ;klog_   LOG_DEBUG, "  case 4\n"
        ; [esp] ^= node
        ; eax ^= sibling node
        ; ebx ^= parent node
        test    ebx, ebx
        jz      .case_5
        cmp     [ebx + rb_tree_node_t._.color], 0
        je      .case_5

        test    eax, eax
        jz      .case_4_exit2
        cmp     [eax + rb_tree_node_t._.color], 0
        jne     .case_5

        mov     ecx, [eax + rb_tree_node_t._.left_ptr]
        test    ecx, ecx
        jz      @f
        cmp     [ecx + rb_tree_node_t._.color], 0
        jne     .case_5

    @@: mov     ecx, [eax + rb_tree_node_t._.right_ptr]
        test    ecx, ecx
        jz      .case_4_exit
        cmp     [ecx + rb_tree_node_t._.color], 0
        jne     .case_5

  .case_4_exit:
        or      [eax + rb_tree_node_t._.color], 1

  .case_4_exit2:
        and     [ebx + rb_tree_node_t._.color], 0
        jmp     .exit_pop

  .case_5:
        ;klog_   LOG_DEBUG, "  case 5\n"
        ; [esp] ^= node
        ; eax ^= sibling node
        ; ebx ^= parent node
        test    ebx, ebx
        jz      .exit_pop
        test    eax, eax
        jz      .exit_pop

        cmp     [eax + rb_tree_node_t._.color], 0
        jne     .case_6

        mov     ecx, [ebx + rb_tree_node_t._.left_ptr]
        cmp     ecx, [esp]
        jne     .case_5_check_other

        mov     ecx, [eax + rb_tree_node_t._.right_ptr]
        test    ecx, ecx
        jz      @f
        cmp     [ecx + rb_tree_node_t._.color], 0
        jne     .case_5_check_other

    @@: mov     ecx, [eax + rb_tree_node_t._.left_ptr]
        test    ecx, ecx
        jz      .case_5_check_other
        cmp     [ecx + rb_tree_node_t._.color], 0
        je      .case_5_check_other

        or      [eax + rb_tree_node_t._.color], 1
        and     [ecx + rb_tree_node_t._.color], 0
        call    util.b_tree._.rotate_right
        jmp     .case_6

  .case_5_check_other:
        mov     ecx, [eax + rb_tree_node_t._.left_ptr]
        test    ecx, ecx
        jz      @f
        cmp     [ecx + rb_tree_node_t._.color], 0
        jne     .case_6

    @@: mov     ecx, [eax + rb_tree_node_t._.right_ptr]
        test    ecx, ecx
        jz      .case_6
        cmp     [ecx + rb_tree_node_t._.color], 0
        je      .case_6

        or      [eax + rb_tree_node_t._.color], 1
        and     [ecx + rb_tree_node_t._.color], 0
        call    util.b_tree._.rotate_left

  .case_6:
        ;klog_   LOG_DEBUG, "  case 6\n"
        ; [esp] ^= node
        mov     eax, [esp]
        mov     ebx, [eax + rb_tree_node_t._.parent_ptr]
        call    util.b_tree._.get_sibling

        mov     cl, [ebx + rb_tree_node_t._.color]
        mov     [eax + rb_tree_node_t._.color], cl
        and     [ebx + rb_tree_node_t._.color], 0

        mov     ecx, [ebx + rb_tree_node_t._.left_ptr]
        cmp     ecx, [esp]
        xchg    eax, ebx
        jne     .case_6_fix_left

        mov     ecx, [ebx + rb_tree_node_t._.right_ptr]
        test    ecx, ecx
        jz      @f

        and     [ecx + rb_tree_node_t._.color], 0

    @@: call    util.b_tree._.rotate_left
        jmp     .exit_pop

  .case_6_fix_left:
        mov     ecx, [ebx + rb_tree_node_t._.left_ptr]
        test    ecx, ecx
        jz      @f

        and     [ecx + rb_tree_node_t._.color], 0

    @@: call    util.b_tree._.rotate_right

  .exit_pop:
        pop     eax

  .exit:
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc util.b_tree._.get_root ;//////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> eax ^= non-null node
;-----------------------------------------------------------------------------------------------------------------------
;< eax ^= root node
;-----------------------------------------------------------------------------------------------------------------------
        klog_   LOG_TRACE, "util.b_tree._.get_root(%x)\n", eax
        test    eax, eax
        jz      .exit

  .next_parent_node:
        mov     ecx, [eax + rb_tree_node_t._.parent_ptr]
        test    ecx, ecx
        jz      .exit

        xchg    eax, ecx
        jmp     .next_parent_node

  .exit:
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc util.b_tree._.get_grandparent ;///////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> eax ^= node
;-----------------------------------------------------------------------------------------------------------------------
;< eax ^= grandparent node
;-----------------------------------------------------------------------------------------------------------------------
        test    eax, eax
        jz      .exit

        mov     eax, [eax + rb_tree_node_t._.parent_ptr]
        test    eax, eax
        jz      .exit

        mov     eax, [eax + rb_tree_node_t._.parent_ptr]

  .exit:
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc util.b_tree._.get_uncle ;/////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> eax ^= node
;-----------------------------------------------------------------------------------------------------------------------
;< eax ^= uncle node
;< ecx ^= grandparent node
;-----------------------------------------------------------------------------------------------------------------------
        mov     ecx, [eax + rb_tree_node_t._.parent_ptr]

        call    util.b_tree._.get_grandparent
        test    eax, eax
        jz      .error

        xchg    eax, ecx
        cmp     eax, [ecx + rb_tree_node_t._.left_ptr]
        mov     eax, [ecx + rb_tree_node_t._.right_ptr]
        je      .exit

        mov     eax, [ecx + rb_tree_node_t._.left_ptr]

  .exit:
        ret

  .error:
        xor     ecx, ecx
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc util.b_tree._.get_sibling ;///////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> eax ^= node
;-----------------------------------------------------------------------------------------------------------------------
;< eax ^= sibling node
;-----------------------------------------------------------------------------------------------------------------------
        mov     ecx, [eax + rb_tree_node_t._.parent_ptr]

        mov     edx, [ecx + rb_tree_node_t._.left_ptr]
        cmp     eax, edx
        xchg    eax, edx
        jne     .exit

        mov     eax, [ecx + rb_tree_node_t._.right_ptr]

  .exit:
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc util.b_tree._.swap ;//////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> eax ^= first node
;> ebx ^= second node
;-----------------------------------------------------------------------------------------------------------------------
        klog_   LOG_TRACE, "util.b_tree._.swap(%x,%x)\n", eax, ebx
        push    ecx edx ebp

        ; T* dummy;
        add     esp, -4
        mov     ebp, esp

        push    dword[eax + rb_tree_node_t._.color] dword[ebx + rb_tree_node_t._.color]

        ; T* ll = l->left;
        mov     ecx, [eax + rb_tree_node_t._.left_ptr]
        ; T* llx = check_node(ll, l, r);
        call    .check_node
        push    edx

        ; T** llp = ll ? &llx->parent : &dummy;
        test    ecx, ecx
        lea     ecx, [edx + rb_tree_node_t._.parent_ptr]
        jnz     .push_first_left
        mov     ecx, ebp

  .push_first_left:
        push    ecx

        ; T* lr = l->right;
        mov     ecx, [eax + rb_tree_node_t._.right_ptr]
        ; T* lrx = check_node(lr, l, r);
        call    .check_node
        push    edx

        ; T** lrp = lr ? &lrx->parent : &dummy;
        test    ecx, ecx
        lea     ecx, [edx + rb_tree_node_t._.parent_ptr]
        jnz     .push_first_right
        mov     ecx, ebp

  .push_first_right:
        push    ecx

        ; T* lp = l->parent;
        mov     ecx, [eax + rb_tree_node_t._.parent_ptr]
        ; T* lpx = check_node(lp, l, r);
        call    .check_node
        push    edx

        ; T** lpc = lp ? (lp->left == l ? &lpx->left : &lpx->right) : &dummy;
        test    ecx, ecx
        jz      .dummy_first_parent
        add     edx, rb_tree_node_t._.left_ptr
        cmp     eax, [ecx + rb_tree_node_t._.left_ptr]
        je      .push_first_parent
        add     edx, rb_tree_node_t._.right_ptr - rb_tree_node_t._.left_ptr
        jmp     .push_first_parent

  .dummy_first_parent:
        mov     edx, ebp

  .push_first_parent:
        push    edx

        xchg    eax, ebx

        ; T* rl = r->left;
        mov     ecx, [eax + rb_tree_node_t._.left_ptr]
        ; T* rlx = check_node(rl, r, l);
        call    .check_node
        push    edx

        ; T** rlp = rl ? &rlx->parent : &dummy;
        test    ecx, ecx
        lea     ecx, [edx + rb_tree_node_t._.parent_ptr]
        jnz     .push_second_left
        mov     ecx, ebp

  .push_second_left:
        push    ecx

        ; T* rr = r->right;
        mov     ecx, [eax + rb_tree_node_t._.right_ptr]
        ; T* rrx = check_node(rr, r, l);
        call    .check_node
        push    edx

        ; T** rrp = rr ? &rrx->parent : &dummy;
        test    ecx, ecx
        lea     ecx, [edx + rb_tree_node_t._.parent_ptr]
        jnz     .push_second_right
        mov     ecx, ebp

  .push_second_right:
        push    ecx

        ; T* rp = r->parent;
        mov     ecx, [eax + rb_tree_node_t._.parent_ptr]
        ; T* rpx = check_node(rp, r, l);
        call    .check_node
        push    edx

        ; T** rpc = lp ? (rp->left == r ? &rpx->left : &rpx->right) : &dummy;
        test    ecx, ecx
        jz      .dummy_second_parent
        add     edx, rb_tree_node_t._.left_ptr
        cmp     eax, [ecx + rb_tree_node_t._.left_ptr]
        je      .push_second_parent
        add     edx, rb_tree_node_t._.right_ptr - rb_tree_node_t._.left_ptr
        jmp     .push_second_parent

  .dummy_second_parent:
        mov     edx, ebp

  .push_second_parent:
        push    edx

        xchg    eax, ebx

        ; *rpc = l;
        pop     ecx
        mov     [ecx], eax
        ; l->parent = rpx;
        pop     [eax + rb_tree_node_t._.parent_ptr]
        ; *rrp = l;
        pop     ecx
        mov     [ecx], eax
        ; l->right = rrx;
        pop     [eax + rb_tree_node_t._.right_ptr]
        ; *rlp = l;
        pop     ecx
        mov     [ecx], eax
        ; l->left = rlx;
        pop     [eax + rb_tree_node_t._.left_ptr]

        xchg    eax, ebx

        ; *lpc = r;
        pop     ecx
        mov     [ecx], eax
        ; r->parent = lpx;
        pop     [eax + rb_tree_node_t._.parent_ptr]
        ; *lrp = r;
        pop     ecx
        mov     [ecx], eax
        ; r->right = lrx;
        pop     [eax + rb_tree_node_t._.right_ptr]
        ; *llp = r;
        pop     ecx
        mov     [ecx], eax
        ; r->left = llx;
        pop     [eax + rb_tree_node_t._.left_ptr]

        pop     dword[ebx + rb_tree_node_t._.color] dword[eax + rb_tree_node_t._.color]

        add     esp, 4
        pop     ebp edx ecx
        ret

;-----------------------------------------------------------------------------------------------------------------------
  .check_node: ;::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
;-----------------------------------------------------------------------------------------------------------------------
        ; return n == r ? l : n;
        cmp     ecx, ebx
        mov     edx, ecx
        jne     @f

        mov     edx, eax

    @@: ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc util.b_tree._.fix_parent_pointer ;////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> eax ^= old child node
;> ebx ^= new child node
;> ecx ^= parent node
;-----------------------------------------------------------------------------------------------------------------------
        test    ecx, ecx
        jz      .exit

        cmp     eax, [ecx + rb_tree_node_t._.left_ptr]
        jne     @f

        mov     [ecx + rb_tree_node_t._.left_ptr], ebx
        jmp     .exit

    @@: mov     [ecx + rb_tree_node_t._.right_ptr], ebx

  .exit:
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc util.b_tree._.replace ;///////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> eax ^= first node
;> ebx ^= second node
;-----------------------------------------------------------------------------------------------------------------------
        klog_   LOG_TRACE, "util.b_tree._.replace(%x,%x)\n", eax, ebx
        mov     ecx, [eax + rb_tree_node_t._.parent_ptr]
        mov     [ebx + rb_tree_node_t._.parent_ptr], ecx
        call    util.b_tree._.fix_parent_pointer

        and     [eax + rb_tree_node_t._.parent_ptr], 0
        and     [eax + rb_tree_node_t._.left_ptr], 0
        and     [eax + rb_tree_node_t._.right_ptr], 0
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc util.b_tree._.rotate_left ;///////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> eax ^= node
;-----------------------------------------------------------------------------------------------------------------------
        klog_   LOG_TRACE, "util.b_tree._.rotate_left(%x)\n", eax
        push    eax ecx edx

        mov     ecx, eax
        mov     eax, [ecx + rb_tree_node_t._.right_ptr]
        mov     edx, [eax + rb_tree_node_t._.left_ptr]

        mov     [ecx + rb_tree_node_t._.right_ptr], edx
        test    edx, edx
        jz      @f
        mov     [edx + rb_tree_node_t._.parent_ptr], ecx

    @@: mov     edx, [ecx + rb_tree_node_t._.parent_ptr]
        mov     [eax + rb_tree_node_t._.parent_ptr], edx
        test    edx, edx
        jz      .finish

        cmp     ecx, [edx + rb_tree_node_t._.left_ptr]
        jne     @f

        mov     [edx + rb_tree_node_t._.left_ptr], eax
        jmp     .finish

    @@: mov     [edx + rb_tree_node_t._.right_ptr], eax

  .finish:
        mov     [eax + rb_tree_node_t._.left_ptr], ecx
        mov     [ecx + rb_tree_node_t._.parent_ptr], eax

        pop     edx ecx eax
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc util.b_tree._.rotate_right ;//////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> eax ^= node
;-----------------------------------------------------------------------------------------------------------------------
        klog_   LOG_TRACE, "util.b_tree._.rotate_right(%x)\n", eax
        push    eax ecx edx

        mov     ecx, eax
        mov     eax, [ecx + rb_tree_node_t._.left_ptr]
        mov     edx, [eax + rb_tree_node_t._.right_ptr]

        mov     [ecx + rb_tree_node_t._.left_ptr], edx
        test    edx, edx
        jz      @f
        mov     [edx + rb_tree_node_t._.parent_ptr], ecx

    @@: mov     edx, [ecx + rb_tree_node_t._.parent_ptr]
        mov     [eax + rb_tree_node_t._.parent_ptr], edx
        test    edx, edx
        jz      .finish

        cmp     ecx, [edx + rb_tree_node_t._.left_ptr]
        jne     @f

        mov     [edx + rb_tree_node_t._.left_ptr], eax
        jmp     .finish

    @@: mov     [edx + rb_tree_node_t._.right_ptr], eax

  .finish:
        mov     [eax + rb_tree_node_t._.right_ptr], ecx
        mov     [ecx + rb_tree_node_t._.parent_ptr], eax

        pop     edx ecx eax
        ret
kendp
