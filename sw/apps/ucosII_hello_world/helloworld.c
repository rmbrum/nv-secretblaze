/*
*********************************************************************************************************
*                                               uC/OS-II
*                                         The Real-Time Kernel
*
*                                         Hello World Example
*
*
* Description:  Shows an example of how to use uCOS-II.  
*********************************************************************************************************
*/

#include "includes.h"

/*
*********************************************************************************************************
*                                            GLOBAL VARIABLES
*********************************************************************************************************
*/

static  OS_STK  FirstTaskStk  [TASK_STK_SIZE];                               
static  OS_STK  SecondTaskStk [TASK_STK_SIZE];

/*
*********************************************************************************************************
*                                              PROTOTYPES
*********************************************************************************************************
*/

static  void  FirstTask     (void *p_arg);
static  void  SecondTask    (void *p_arg); 
static  void  AppTaskCreate (); 

/*
*********************************************************************************************************
*                                                main()
* 
* Description: This is the 'standard' C startup entry point.  main() does the following:
*              
*              1) Initialize uC/OS-II
*              2) Create a single task
*              3) Start uC/OS-II
*
* Arguments  : None
*
* Returns    : main() should NEVER return
*********************************************************************************************************
*/

int  main (void)
{
    CPU_INT08U    err;

    BSP_IntDisAll();
    OSInit();                                   /* Initialize uC/OS-II                                 */

    OSTaskCreateExt(FirstTask,
                   (void *)0,
                   &FirstTaskStk[TASK_STK_SIZE - 1],
                   TASK1_ID,                    
                   TASK1_PRIO,
                   &FirstTaskStk[0],
                   TASK_STK_SIZE,
                   (void *)0,
                   OS_TASK_OPT_STK_CHK | OS_TASK_OPT_STK_CLR); 
    
    OSTaskNameSet(TASK1_PRIO, (CPU_INT08U *)"FirstTask", &err);

    OSStart();                                  /* Start Multitasking                                  */

    return 0;                                   /* Process should never reach this point               */
}

/*
*********************************************************************************************************
*                                            FirstTask()
* 
* Description: This is the first task executed by uC/OS-II following OSStart()
*              
* Arguments  : p_arg    Argument passed to this task when task is created.  The argument is not used.
*
* Returns    : None
*********************************************************************************************************
*/

static  void  FirstTask (void *p_arg)
{
    p_arg = p_arg;    

    BSP_InitIO();
#if OS_TASK_STAT_EN > 0
    OSStatInit();
#endif
    AppTaskCreate();                             /* The other tasks in the application are generally   */
                                                 /* created in a separate function to reduce clutter   */
                                                 /* in main                                            */

    while (1)
    {
        e_printf("First task says Hello World\n");
        OSTimeDlyHMSM(0,0,1,0);
    }
}

/*
*********************************************************************************************************
*                                             SecondTask()
* 
* Description: This is the first task executed by uC/OS-II following OSStart()
*              
* Arguments  : p_arg    Argument passed to this task when task is created.  The argument is not used.
*
* Returns    : None
*********************************************************************************************************
*/

static  void  SecondTask (void *p_arg)
{
    p_arg = p_arg;    

    while (1)
    {
        e_printf("Second task says Hello World\n");
        OSTimeDlyHMSM(0,0,3,0);
    }
}

/*
*********************************************************************************************************
*                                          AppTaskCreate()
* 
* Description: A seperate function in order to create all tasks
*              
* Arguments  : None
*
* Returns    : None
*********************************************************************************************************
*/

static  void  AppTaskCreate (void)
{
	CPU_INT08U err;
	
	OSTaskCreateExt(SecondTask,
                     (void *)0,
                     &SecondTaskStk[TASK_STK_SIZE - 1],
                     TASK2_ID,
                     TASK2_PRIO,
                     &SecondTaskStk[0],
                     TASK_STK_SIZE,
                     (void *)0,
                     OS_TASK_OPT_STK_CHK | OS_TASK_OPT_STK_CLR);
      
      OSTaskNameSet(TASK1_PRIO, (CPU_INT08U *)"SecondTask", &err);
}

