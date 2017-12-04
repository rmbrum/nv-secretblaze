/* 
 ****************************************************************************
 *
 *                   "DHRYSTONE" Benchmark Program
 *                   -----------------------------
 *
 *  Version:    C, Version 2.1
 *
 *  File:       dhry_1.c (part 2 of 3)
 *
 *  Date:       May 25, 1988
 *
 *  Author:     Reinhold P. Weicker
 *
 ****************************************************************************
 */

#include "dhry.h"

/* Global Variables: */

Rec_Pointer     Ptr_Glob,
                Next_Ptr_Glob;
int             Int_Glob;
Boolean         Bool_Glob;
char            Ch_1_Glob,
                Ch_2_Glob;
int             Arr_1_Glob [50];
int             Arr_2_Glob [50] [50];

Enumeration     Func_1 ();
  /* forward declaration necessary since Enumeration may not simply be int */

#ifndef REG
        Boolean Reg = false;
#define REG
        /* REG becomes defined as empty */
        /* i.e. no register variables   */
#else
        Boolean Reg = true;
#endif

volatile long   Begin_Time,
                End_Time,
                User_Time;
float           Microseconds,
                Dhrystones_Per_Second;

/* end of variables for time measurement */

#ifdef NO_MALLOC
Rec_Type tmp_var1, tmp_var2;
#endif

main ()
/*****/

  /* main program, corresponds to procedures        */
  /* Main and Proc_0 in the Ada version             */
{
        One_Fifty       Int_1_Loc;
  REG   One_Fifty       Int_2_Loc;
        One_Fifty       Int_3_Loc;
  REG   char            Ch_Index;
        Enumeration     Enum_Loc;
        Str_30          Str_1_Loc;
        Str_30          Str_2_Loc;
  REG   int             Run_Index;
  REG   int             Number_Of_Runs;

#ifdef NO_MALLOC
  Next_Ptr_Glob = (Rec_Pointer) &tmp_var1;
  Ptr_Glob = (Rec_Pointer) &tmp_var2;
#else
  Next_Ptr_Glob = (Rec_Pointer) malloc (sizeof (Rec_Type));
  Ptr_Glob = (Rec_Pointer) malloc (sizeof (Rec_Type));
#endif

  Ptr_Glob->Ptr_Comp                    = Next_Ptr_Glob;
  Ptr_Glob->Discr                       = Ident_1;
  Ptr_Glob->variant.var_1.Enum_Comp     = Ident_3;
  Ptr_Glob->variant.var_1.Int_Comp      = 40;
  strcpy (Ptr_Glob->variant.var_1.Str_Comp,
          "DHRYSTONE PROGRAM, SOME STRING");
  strcpy (Str_1_Loc, "DHRYSTONE PROGRAM, 1'ST STRING");

  Arr_2_Glob [8][7] = 10;
        /* Was missing in published program. Without this statement,    */
        /* Arr_2_Glob [8][7] would have an undefined value.             */
        /* Warning: With 16-Bit processors and Number_Of_Runs > 32000,  */
        /* overflow may occur for this array element.                   */

#ifdef VERBOSE_MODE
  e_printf ("\n");
  e_printf ("Dhrystone Benchmark, Version 2.1 (Language: C)\n");
  e_printf ("\n");
  if (Reg)
  {
    e_printf ("Program compiled with 'register' attribute\n");
    e_printf ("\n");
  }
  else
  {
    e_printf ("Program compiled without 'register' attribute\n");
    e_printf ("\n");
  }
#endif

  Number_Of_Runs = 10000;
  
#ifdef VERBOSE_MODE
  e_printf ("Execution starts, %d runs through Dhrystone\n", Number_Of_Runs);
#endif  

  /***************/
  /* Start timer */
  /***************/

  {
    /* Begin_Time = 0x0; */

    timer_1_reset();
    timer_1_init(TIMER_MAX_VALUE);
    timer_1_enable();

    for (Run_Index = 1; Run_Index <= Number_Of_Runs; ++Run_Index)
    {

      Proc_5();
      Proc_4();
        /* Ch_1_Glob == 'A', Ch_2_Glob == 'B', Bool_Glob == true */
      Int_1_Loc = 2;
      Int_2_Loc = 3;
      strcpy (Str_2_Loc, "DHRYSTONE PROGRAM, 2'ND STRING");
      Enum_Loc = Ident_2;
      Bool_Glob = ! Func_2 (Str_1_Loc, Str_2_Loc);
        /* Bool_Glob == 1 */
      while (Int_1_Loc < Int_2_Loc)  /* loop body executed once */
      {
        Int_3_Loc = 5 * Int_1_Loc - Int_2_Loc;
          /* Int_3_Loc == 7 */
        Proc_7 (Int_1_Loc, Int_2_Loc, &Int_3_Loc);
          /* Int_3_Loc == 7 */
        Int_1_Loc += 1;
      } /* while */
        /* Int_1_Loc == 3, Int_2_Loc == 3, Int_3_Loc == 7 */
      Proc_8 (Arr_1_Glob, Arr_2_Glob, Int_1_Loc, Int_3_Loc);
        /* Int_Glob == 5 */
      Proc_1 (Ptr_Glob);
      for (Ch_Index = 'A'; Ch_Index <= Ch_2_Glob; ++Ch_Index)
                               /* loop body executed twice */
      {
        if (Enum_Loc == Func_1 (Ch_Index, 'C'))
            /* then, not executed */
          {
          Proc_6 (Ident_1, &Enum_Loc);
          strcpy (Str_2_Loc, "DHRYSTONE PROGRAM, 3'RD STRING");
          Int_2_Loc = Run_Index;
          Int_Glob = Run_Index;
          }
      }
        /* Int_1_Loc == 3, Int_2_Loc == 3, Int_3_Loc == 7 */
      Int_2_Loc = Int_2_Loc * Int_1_Loc;
      Int_1_Loc = Int_2_Loc / Int_3_Loc;
      Int_2_Loc = 7 * (Int_2_Loc - Int_3_Loc) - Int_1_Loc;
        /* Int_1_Loc == 1, Int_2_Loc == 13, Int_3_Loc == 7 */
      Proc_2 (&Int_1_Loc);
        /* Int_1_Loc == 5 */

    } /* loop "for Run_Index" */

  /**************/
  /* Stop timer */
  /**************/

    End_Time = timer_1_getval();
  }

#ifdef VERBOSE_MODE
  e_printf ("Execution ends\n");
  e_printf ("\n");

  e_printf ("Final values of the variables used in the benchmark:\n");
  e_printf ("\n");
  e_printf ("Int_Glob:            %d\n", Int_Glob);
  e_printf ("        should be:   %d\n", 5);
  e_printf ("Bool_Glob:           %d\n", Bool_Glob);
  e_printf ("        should be:   %d\n", 1);
  e_printf ("Ch_1_Glob:           %c\n", Ch_1_Glob);
  e_printf ("        should be:   %c\n", 'A');
  e_printf ("Ch_2_Glob:           %c\n", Ch_2_Glob);
  e_printf ("        should be:   %c\n", 'B');
  e_printf ("Arr_1_Glob[8]:       %d\n", Arr_1_Glob[8]);
  e_printf ("        should be:   %d\n", 7);
  e_printf ("Arr_2_Glob[8][7]:    %d\n", Arr_2_Glob[8][7]);
  e_printf ("        should be:   %d\n", Number_Of_Runs+10);
  e_printf ("Ptr_Glob->\n");
  e_printf ("  Ptr_Comp:          0x%08x\n", (int) Ptr_Glob->Ptr_Comp);
  e_printf ("        should be:   (implementation-dependent)\n");
  e_printf ("  Discr:             %d\n", Ptr_Glob->Discr);
  e_printf ("        should be:   %d\n", 0);
  e_printf ("  Enum_Comp:         %d\n", Ptr_Glob->variant.var_1.Enum_Comp);
  e_printf ("        should be:   %d\n", 2);
  e_printf ("  Int_Comp:          %d\n", Ptr_Glob->variant.var_1.Int_Comp);
  e_printf ("        should be:   %d\n", 17);
  e_printf ("  Str_Comp:          %s\n", Ptr_Glob->variant.var_1.Str_Comp);
  e_printf ("        should be:   DHRYSTONE PROGRAM, SOME STRING\n");
  e_printf ("Next_Ptr_Glob->\n");
  e_printf ("  Ptr_Comp:          0x%08x\n", (int) Next_Ptr_Glob->Ptr_Comp);
  e_printf ("        should be:   (implementation-dependent), same as above\n");
  e_printf ("  Discr:             %d\n", Next_Ptr_Glob->Discr);
  e_printf ("        should be:   %d\n", 0);
  e_printf ("  Enum_Comp:         %d\n", Next_Ptr_Glob->variant.var_1.Enum_Comp);
  e_printf ("        should be:   %d\n", 1);
  e_printf ("  Int_Comp:          %d\n", Next_Ptr_Glob->variant.var_1.Int_Comp);
  e_printf ("        should be:   %d\n", 18);
  e_printf ("  Str_Comp:          %s\n",
                                Next_Ptr_Glob->variant.var_1.Str_Comp);
  e_printf ("        should be:   DHRYSTONE PROGRAM, SOME STRING\n");
  e_printf ("Int_1_Loc:           %d\n", Int_1_Loc);
  e_printf ("        should be:   %d\n", 5);
  e_printf ("Int_2_Loc:           %d\n", Int_2_Loc);
  e_printf ("        should be:   %d\n", 13);
  e_printf ("Int_3_Loc:           %d\n", Int_3_Loc);
  e_printf ("        should be:   %d\n", 7);
  e_printf ("Enum_Loc:            %d\n", Enum_Loc);
  e_printf ("        should be:   %d\n", 1);
  e_printf ("Str_1_Loc:           %s\n", Str_1_Loc);
  e_printf ("        should be:   DHRYSTONE PROGRAM, 1'ST STRING\n");
  e_printf ("Str_2_Loc:           %s\n", Str_2_Loc);
  e_printf ("        should be:   DHRYSTONE PROGRAM, 2'ND STRING\n");
  e_printf ("\n");
#endif

  /* calculate and print dmips/mhz */
#ifdef VERBOSE_MODE
  e_printf ("Ticks          : %d\n",End_Time*C_S_CLK_DIV);
#endif
  float dmips = ((float)Number_Of_Runs/1757*FREQ_CORE_HZ/(End_Time*C_S_CLK_DIV)); 
#ifdef VERBOSE_MODE
  e_printf ("DMIPS          : %d\n",(int)(dmips));
  e_printf ("Proc Frequency : %d Hz\n",FREQ_CORE_HZ);
#endif
  e_printf ("DMIPS/MHz      : %d/1000\n",(int)(1000 * (float)dmips/(FREQ_CORE_HZ/1000000)));

}


Proc_1 (Ptr_Val_Par)
/******************/

REG Rec_Pointer Ptr_Val_Par;
    /* executed once */
{
  REG Rec_Pointer Next_Record = Ptr_Val_Par->Ptr_Comp;
                                        /* == Ptr_Glob_Next */
  /* Local variable, initialized with Ptr_Val_Par->Ptr_Comp,    */
  /* corresponds to "rename" in Ada, "with" in Pascal           */

  structassign (*Ptr_Val_Par->Ptr_Comp, *Ptr_Glob);
  Ptr_Val_Par->variant.var_1.Int_Comp = 5;
  Next_Record->variant.var_1.Int_Comp
        = Ptr_Val_Par->variant.var_1.Int_Comp;
  Next_Record->Ptr_Comp = Ptr_Val_Par->Ptr_Comp;
  Proc_3 (&Next_Record->Ptr_Comp);
    /* Ptr_Val_Par->Ptr_Comp->Ptr_Comp
                        == Ptr_Glob->Ptr_Comp */
  if (Next_Record->Discr == Ident_1)
    /* then, executed */
  {
    Next_Record->variant.var_1.Int_Comp = 6;
    Proc_6 (Ptr_Val_Par->variant.var_1.Enum_Comp,
           &Next_Record->variant.var_1.Enum_Comp);
    Next_Record->Ptr_Comp = Ptr_Glob->Ptr_Comp;
    Proc_7 (Next_Record->variant.var_1.Int_Comp, 10,
           &Next_Record->variant.var_1.Int_Comp);
  }
  else /* not executed */
    structassign (*Ptr_Val_Par, *Ptr_Val_Par->Ptr_Comp);
} /* Proc_1 */


Proc_2 (Int_Par_Ref)
/******************/
    /* executed once */
    /* *Int_Par_Ref == 1, becomes 4 */

One_Fifty   *Int_Par_Ref;
{
  One_Fifty  Int_Loc;
  Enumeration   Enum_Loc;

  Int_Loc = *Int_Par_Ref + 10;
  do /* executed once */
    if (Ch_1_Glob == 'A')
      /* then, executed */
    {
      Int_Loc -= 1;
      *Int_Par_Ref = Int_Loc - Int_Glob;
      Enum_Loc = Ident_1;
    } /* if */
  while (Enum_Loc != Ident_1); /* true */
} /* Proc_2 */


Proc_3 (Ptr_Ref_Par)
/******************/
    /* executed once */
    /* Ptr_Ref_Par becomes Ptr_Glob */

Rec_Pointer *Ptr_Ref_Par;

{
  if (Ptr_Glob != Null)
    /* then, executed */
    *Ptr_Ref_Par = Ptr_Glob->Ptr_Comp;
  Proc_7 (10, Int_Glob, &Ptr_Glob->variant.var_1.Int_Comp);
} /* Proc_3 */


Proc_4 () /* without parameters */
/*******/
    /* executed once */
{
  Boolean Bool_Loc;

  Bool_Loc = Ch_1_Glob == 'A';
  Bool_Glob = Bool_Loc | Bool_Glob;
  Ch_2_Glob = 'B';
} /* Proc_4 */


Proc_5 () /* without parameters */
/*******/
    /* executed once */
{
  Ch_1_Glob = 'A';
  Bool_Glob = false;
} /* Proc_5 */


