// dhrystone.c - Dhrystone 2.1 benchmark, minimal bare-metal port for RV32IM.
// Stripped to fit in 4KB instruction memory. No printf/string.h dependencies.
// Results stored to dmem[0..5] for testbench readout.
//
// Reference: Weicker, R.P., "Dhrystone: A Synthetic Systems Programming Benchmark,"
//            Communications of the ACM, vol.27, no.10, pp.1013-1030, October 1984.

#define RESULT_CYCLES    (*(volatile unsigned int *)0x00000000)
#define RESULT_INSTRS    (*(volatile unsigned int *)0x00000004)
#define RESULT_BRANCHES  (*(volatile unsigned int *)0x00000008)
#define RESULT_MISPRED   (*(volatile unsigned int *)0x0000000C)
#define RESULT_DHRYSTONES (*(volatile unsigned int *)0x00000010)
#define RESULT_CHECKSUM  (*(volatile unsigned int *)0x00000014)

static unsigned int csr_mcycle(void)   { unsigned int v; asm volatile("csrr %0, mcycle"   : "=r"(v)); return v; }
static unsigned int csr_minstret(void) { unsigned int v; asm volatile("csrr %0, minstret" : "=r"(v)); return v; }
static unsigned int csr_branches(void) { unsigned int v; asm volatile("csrr %0, 0xB04"    : "=r"(v)); return v; }
static unsigned int csr_mispred(void)  { unsigned int v; asm volatile("csrr %0, 0xB03"    : "=r"(v)); return v; }

// Dhrystone types
typedef int Enumeration;
#define Ident_1 0
#define Ident_2 1
#define Ident_3 2
#define Ident_4 3
#define Ident_5 4

typedef struct record {
    struct record *Ptr_Comp;
    Enumeration   Discr;
    union {
        struct { Enumeration Enum_Comp; int Int_Comp; } var_1;
        struct { Enumeration Enum_Comp_2; int Int_Comp_2; } var_2;
    } variant;
} Rec_Type;

#define NUM_RUNS 100

// Global variables (Dhrystone requires these)
static Rec_Type Record_Glob, Next_Record_Glob;
static int Int_Glob;
static Enumeration Enum_Glob;
static int Arr_1_Glob[25];
static int Arr_2_Glob[25][25];

static Enumeration Func_1(int Ch_1_Par, int Ch_2_Par) {
    int Ch_1_Loc = Ch_1_Par;
    int Ch_2_Loc = Ch_1_Loc;
    if (Ch_2_Loc != Ch_2_Par)
        return Ident_1;
    else
        return Ident_2;
}

static int Func_2(int *Str_1, int *Str_2) {
    int Int_Loc = 2;
    while (Int_Loc <= 2) {
        if (Func_1(Str_1[Int_Loc], Str_2[Int_Loc + 1]) == Ident_1) {
            Int_Loc += 1;
        }
    }
    if (Str_1[0] > Str_2[0])
        return 1;
    else
        return 0;
}

static int Func_3(Enumeration Enum_Par) {
    if (Enum_Par == Ident_3)
        return 1;
    else
        return 0;
}

static void Proc_6(Enumeration Enum_Val, Enumeration *Enum_Ref) {
    *Enum_Ref = Enum_Val;
    if (!Func_3(Enum_Val))
        *Enum_Ref = Ident_4;
    switch (Enum_Val) {
        case Ident_1: *Enum_Ref = Ident_1; break;
        case Ident_2: if (Int_Glob > 100) *Enum_Ref = Ident_1; else *Enum_Ref = Ident_4; break;
        case Ident_3: *Enum_Ref = Ident_2; break;
        case Ident_4: break;
        case Ident_5: *Enum_Ref = Ident_3; break;
    }
}

static void Proc_7(int Int_1, int Int_2, int *Int_Par) {
    *Int_Par = Int_2 + Int_1 + 2;
}

static void Proc_8(int *Arr_1, int Arr_2[][25], int Int_1, int Int_2) {
    int Int_Loc = Int_1 + 5;
    Arr_1[Int_Loc] = Int_2;
    Arr_1[Int_Loc + 1] = Arr_1[Int_Loc];
    Arr_1[Int_Loc + 15] = Int_Loc;
    for (int Int_Index = Int_Loc; Int_Index <= Int_Loc + 1; ++Int_Index)
        Arr_2[Int_Loc][Int_Index] = Int_Loc;
    Arr_2[Int_Loc][Int_Loc - 1] += 1;
    Arr_2[Int_Loc + 10][Int_Loc] = Arr_1[Int_Loc];
    Int_Glob = 5;
}

static void Proc_1(Rec_Type *Ptr_Val) {
    Rec_Type *Next = Ptr_Val->Ptr_Comp;
    *Next = Record_Glob;
    Ptr_Val->variant.var_1.Int_Comp = 5;
    Next->variant.var_1.Int_Comp = Ptr_Val->variant.var_1.Int_Comp;
    Next->Ptr_Comp = Ptr_Val->Ptr_Comp;
    Proc_7(10, Int_Glob, &(Ptr_Val->variant.var_1.Int_Comp));
    if (Next->Discr == Ident_1) {
        Next->variant.var_1.Int_Comp = 6;
        Proc_6(Ptr_Val->variant.var_1.Enum_Comp, &(Next->variant.var_1.Enum_Comp));
        Next->Ptr_Comp = Record_Glob.Ptr_Comp;
        Proc_7(Next->variant.var_1.Int_Comp, 10, &(Next->variant.var_1.Int_Comp));
    }
}

int main(void) {
    // Initialize
    Record_Glob.Ptr_Comp = &Next_Record_Glob;
    Record_Glob.Discr = Ident_1;
    Record_Glob.variant.var_1.Enum_Comp = Ident_3;
    Record_Glob.variant.var_1.Int_Comp = 40;
    Next_Record_Glob = Record_Glob;
    Int_Glob = 0;

    int Int_1_Loc, Int_2_Loc, Int_3_Loc;
    Enumeration Enum_Loc;
    int Str_1[4] = {65, 66, 67, 0};
    int Str_2[4] = {65, 66, 68, 0};

    // Snapshot BEFORE
    unsigned int c0 = csr_mcycle();
    unsigned int i0 = csr_minstret();
    unsigned int b0 = csr_branches();
    unsigned int m0 = csr_mispred();
    asm volatile("" ::: "memory");

    // Main Dhrystone loop
    for (int Run_Index = 1; Run_Index <= NUM_RUNS; ++Run_Index) {
        Proc_1(&Record_Glob);
        for (Int_1_Loc = 1; Int_1_Loc <= 2; ++Int_1_Loc) {
            Int_2_Loc = 3 * Int_1_Loc - 1;
            Proc_7(Int_1_Loc, Int_2_Loc, &Int_3_Loc);
        }
        Proc_8(Arr_1_Glob, Arr_2_Glob, Int_1_Loc, Int_3_Loc);
        Proc_6(Ident_1, &Enum_Glob);
        Int_2_Loc = 7;
        Func_2(Str_1, Str_2);
        Int_1_Loc = Int_2_Loc + 1;
    }

    asm volatile("" ::: "memory");
    // Snapshot AFTER
    unsigned int c1 = csr_mcycle();
    unsigned int i1 = csr_minstret();
    unsigned int b1 = csr_branches();
    unsigned int m1 = csr_mispred();

    RESULT_CYCLES     = c1 - c0;
    RESULT_INSTRS     = i1 - i0;
    RESULT_BRANCHES   = b1 - b0;
    RESULT_MISPRED    = m1 - m0;
    RESULT_DHRYSTONES = NUM_RUNS;
    RESULT_CHECKSUM   = (unsigned int)(Int_Glob + Enum_Glob + Int_1_Loc + Int_3_Loc);

    return 0;
}
