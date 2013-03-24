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

struct test.b_tree.node_t rb_tree_node_t
  number dd ?
ends

uglobal
  test.b_tree.root  dd ?
  test.b_tree.nodes rb 14 * sizeof.test.b_tree.node_t
endg

;-----------------------------------------------------------------------------------------------------------------------
kproc test.b_tree.insert_remove_1 ;/////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        KLog    LOG_DEBUG, "---[ test.b_tree.insert_remove_1 ]--->\n"

        and     [test.b_tree.root], 0
        mov     eax, test.b_tree.nodes

irp num, 10,85,15,70,20,60,30,50,65,80,90,40,5,55
{
        mov     [eax + test.b_tree.node_t.number], num
        add     eax, sizeof.test.b_tree.node_t
}

rept 14 i:0
{
        mov     eax, [test.b_tree.root]
        KLog    LOG_DEBUG, "---> "
        call    test.b_tree._.dump
        KLog2   LOG_DEBUG, "\n"

        mov     eax, test.b_tree.nodes + i * sizeof.test.b_tree.node_t
        mov     ebx, [test.b_tree.root]
        mov     ecx, test.b_tree._.compare_nodes
        call    util.rb_tree.insert
        mov     [test.b_tree.root], eax

        KLog    LOG_DEBUG, "---< "
        call    test.b_tree._.dump
        KLog2   LOG_DEBUG, "\n"
}

irp num, 10,85,15,70,20,60,30,50,65,80,90,40,5,55
{
        mov     eax, [test.b_tree.root]
        KLog    LOG_DEBUG, "---> "
        call    test.b_tree._.dump
        KLog2   LOG_DEBUG, "\n"

        add     esp, -sizeof.test.b_tree.node_t
        mov     eax, esp
        mov     [eax + test.b_tree.node_t.number], num
        mov     ebx, [test.b_tree.root]
        mov     ecx, test.b_tree._.compare_nodes
        call    util.b_tree.find
        add     esp, sizeof.test.b_tree.node_t

        push    eax

        call    util.rb_tree.remove
        mov     [test.b_tree.root], eax

        KLog    LOG_DEBUG, "---< "
        call    test.b_tree._.dump
        KLog2   LOG_DEBUG, "\n"

        pop     eax
        mov     dword[eax], 0xcccccccc
        mov     dword[eax + 4], 0xcccccccc
        mov     dword[eax + 8], 0xcccccccc
        mov     dword[eax + 12], 0xcccccccc
        mov     dword[eax + 16], 0xcccccccc
}

        KLog    LOG_DEBUG, "---[ test.b_tree.insert_remove_1 ]---<\n"
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc test.b_tree.insert_remove_2 ;/////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        KLog    LOG_DEBUG, "---[ test.b_tree.insert_remove_2 ]--->\n"

        and     [test.b_tree.root], 0
        mov     eax, test.b_tree.nodes

irp num, 1,2,3,4,5,6,7,8,9,10,11,12,13,14
{
        mov     [eax + test.b_tree.node_t.number], num
        add     eax, sizeof.test.b_tree.node_t
}

rept 14 i:0
{
        mov     eax, [test.b_tree.root]
        KLog    LOG_DEBUG, "---> "
        call    test.b_tree._.dump
        KLog2   LOG_DEBUG, "\n"

        mov     eax, test.b_tree.nodes + i * sizeof.test.b_tree.node_t
        mov     ebx, [test.b_tree.root]
        mov     ecx, test.b_tree._.compare_nodes
        call    util.rb_tree.insert
        mov     [test.b_tree.root], eax

        KLog    LOG_DEBUG, "---< "
        call    test.b_tree._.dump
        KLog2   LOG_DEBUG, "\n"
}

irp num, 1,2,3,4,5,6,7,8,9,10,11,12,13,14
{
        mov     eax, [test.b_tree.root]
        KLog    LOG_DEBUG, "---> "
        call    test.b_tree._.dump
        KLog2   LOG_DEBUG, "\n"

        add     esp, -sizeof.test.b_tree.node_t
        mov     eax, esp
        mov     [eax + test.b_tree.node_t.number], num
        mov     ebx, [test.b_tree.root]
        mov     ecx, test.b_tree._.compare_nodes
        call    util.b_tree.find
        add     esp, sizeof.test.b_tree.node_t

        push    eax

        call    util.rb_tree.remove
        mov     [test.b_tree.root], eax

        KLog    LOG_DEBUG, "---< "
        call    test.b_tree._.dump
        KLog2   LOG_DEBUG, "\n"

        pop     eax
        mov     dword[eax], 0xcccccccc
        mov     dword[eax + 4], 0xcccccccc
        mov     dword[eax + 8], 0xcccccccc
        mov     dword[eax + 12], 0xcccccccc
        mov     dword[eax + 16], 0xcccccccc
}

        KLog    LOG_DEBUG, "---[ test.b_tree.insert_remove_2 ]---<\n"
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc test.b_tree._.compare_nodes ;/////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        push    eax
        mov     eax, [eax + test.b_tree.node_t.number]
        sub     eax, [ebx + test.b_tree.node_t.number]
        pop     eax
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc test.b_tree._.dump ;//////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        test    eax, eax
        jz      .dump_null

        push    0
        mov     byte[esp], 'b'
        cmp     [eax + test.b_tree.node_t._.color], 0
        je      @f
        mov     byte[esp], 'r'

    @@: mov     ecx, esp
        KLog2   LOG_DEBUG, "%s%u", ecx, [eax + test.b_tree.node_t.number]
        add     esp, 4

        cmp     [eax + test.b_tree.node_t._.left_ptr], 0
        jne     @f
        cmp     [eax + test.b_tree.node_t._.right_ptr], 0
        je      .exit

    @@: KLog2   LOG_DEBUG, "("

        push    eax
        mov     eax, [eax + test.b_tree.node_t._.left_ptr]
        call    test.b_tree._.dump
        pop     eax

        KLog2   LOG_DEBUG, ","

        push    eax
        mov     eax, [eax + test.b_tree.node_t._.right_ptr]
        call    test.b_tree._.dump
        pop     eax

        KLog2   LOG_DEBUG, ")"

  .exit:
        ret

  .dump_null:
        KLog2   LOG_DEBUG, "-"
        ret
kendp
