/* USER CODE BEGIN Header */
/**
  ******************************************************************************
  * @file    stm32f4xx_it.c
  * @brief   Interrupt Service Routines.
  ******************************************************************************
  * @attention
  *
  * Copyright (c) 2025 STMicroelectronics.
  * All rights reserved.
  *
  * This software is licensed under terms that can be found in the LICENSE file
  * in the root directory of this software component.
  * If no LICENSE file comes with this software, it is provided AS-IS.
  *
  ******************************************************************************
  */
/* USER CODE END Header */

/* Includes ------------------------------------------------------------------*/
#include "main.h"
#include "stm32f4xx_it.h"
/* Private includes ----------------------------------------------------------*/
/* USER CODE BEGIN Includes */
#include <string.h>
#include <stdio.h>
/* USER CODE END Includes */

/* Private typedef -----------------------------------------------------------*/
/* USER CODE BEGIN TD */

/* USER CODE END TD */

/* Private define ------------------------------------------------------------*/
/* USER CODE BEGIN PD */

/* USER CODE END PD */

/* Private macro -------------------------------------------------------------*/
/* USER CODE BEGIN PM */

/* USER CODE END PM */

/* Private variables ---------------------------------------------------------*/
/* USER CODE BEGIN PV */

/* USER CODE END PV */

/* Private function prototypes -----------------------------------------------*/
/* USER CODE BEGIN PFP */

/* USER CODE END PFP */

/* Private user code ---------------------------------------------------------*/
/* USER CODE BEGIN 0 */

/* USER CODE END 0 */

/* External variables --------------------------------------------------------*/

/* USER CODE BEGIN EV */
extern UART_HandleTypeDef huart2;
/* USER CODE END EV */

/******************************************************************************/
/*           Cortex-M4 Processor Interruption and Exception Handlers          */
/******************************************************************************/
/**
  * @brief This function handles Non maskable interrupt.
  */
void NMI_Handler(void)
{
  /* USER CODE BEGIN NonMaskableInt_IRQn 0 */

  /* USER CODE END NonMaskableInt_IRQn 0 */
  /* USER CODE BEGIN NonMaskableInt_IRQn 1 */
   while (1)
  {
  }
  /* USER CODE END NonMaskableInt_IRQn 1 */
}

/**
  * @brief This function handles Hard fault interrupt.
  */
void HardFault_Handler(void)
{
  /* USER CODE BEGIN HardFault_IRQn 0 */

  /* USER CODE END HardFault_IRQn 0 */
  while (1)
  {
    /* USER CODE BEGIN W1_HardFault_IRQn 0 */
    /* USER CODE END W1_HardFault_IRQn 0 */
  }
}

/**
  * @brief This function handles Memory management fault.
  */
void MemManage_Handler(void)
{
  /* USER CODE BEGIN MemoryManagement_IRQn 0 */

  /* USER CODE END MemoryManagement_IRQn 0 */
  while (1)
  {
    /* USER CODE BEGIN W1_MemoryManagement_IRQn 0 */
    /* USER CODE END W1_MemoryManagement_IRQn 0 */
  }
}

/**
  * @brief This function handles Pre-fetch fault, memory access fault.
  */
void BusFault_Handler(void)
{
  /* USER CODE BEGIN BusFault_IRQn 0 */

  /* USER CODE END BusFault_IRQn 0 */
  while (1)
  {
    /* USER CODE BEGIN W1_BusFault_IRQn 0 */
    /* USER CODE END W1_BusFault_IRQn 0 */
  }
}

/**
  * @brief This function handles Undefined instruction or illegal state.
  */
void UsageFault_Handler(void)
{
  /* USER CODE BEGIN UsageFault_IRQn 0 */

  /* USER CODE END UsageFault_IRQn 0 */
  while (1)
  {
    /* USER CODE BEGIN W1_UsageFault_IRQn 0 */
    /* USER CODE END W1_UsageFault_IRQn 0 */
  }
}

/**
  * @brief This function handles System service call via SWI instruction.
  */
void SVC_Handler(void)
{
  /* USER CODE BEGIN SVCall_IRQn 0 */

  /* USER CODE END SVCall_IRQn 0 */
  /* USER CODE BEGIN SVCall_IRQn 1 */

  /* USER CODE END SVCall_IRQn 1 */
}

/**
  * @brief This function handles Debug monitor.
  */
void DebugMon_Handler(void)
{
  /* USER CODE BEGIN DebugMonitor_IRQn 0 */

  /* USER CODE END DebugMonitor_IRQn 0 */
  /* USER CODE BEGIN DebugMonitor_IRQn 1 */

  /* USER CODE END DebugMonitor_IRQn 1 */
}

/**
  * @brief This function handles Pendable request for system service.
  */
void PendSV_Handler(void)
{
  /* USER CODE BEGIN PendSV_IRQn 0 */

  /* USER CODE END PendSV_IRQn 0 */
  /* USER CODE BEGIN PendSV_IRQn 1 */

  /* USER CODE END PendSV_IRQn 1 */
}

/**
  * @brief This function handles System tick timer.
  */
void SysTick_Handler(void)
{
  /* USER CODE BEGIN SysTick_IRQn 0 */

  /* USER CODE END SysTick_IRQn 0 */
  HAL_IncTick();
  /* USER CODE BEGIN SysTick_IRQn 1 */

  /* USER CODE END SysTick_IRQn 1 */
}

/******************************************************************************/
/* STM32F4xx Peripheral Interrupt Handlers                                    */
/* Add here the Interrupt Handlers for the used peripherals.                  */
/* For the available peripheral interrupt handler names,                      */
/* please refer to the startup file (startup_stm32f4xx.s).                    */
/******************************************************************************/

/**
  * @brief This function handles EXTI line[15:10] interrupts.
  */
void EXTI15_10_IRQHandler(void)
{
  /* USER CODE BEGIN EXTI15_10_IRQn 0 */

  /* USER CODE END EXTI15_10_IRQn 0 */
  HAL_GPIO_EXTI_IRQHandler(CLOCK_Pin);
  /* USER CODE BEGIN EXTI15_10_IRQn 1 */

  /* USER CODE END EXTI15_10_IRQn 1 */
}

/* USER CODE BEGIN 1 */
void HAL_GPIO_EXTI_Callback(uint16_t GPIO_Pin)
{
  if(GPIO_Pin == CLOCK_Pin)
  {
    // Only capture when system power is on
    if(!HAL_GPIO_ReadPin(SYS_PWR_GPIO_Port, SYS_PWR_Pin)) {
      return;  // System is off, ignore this clock edge
    }

    static uint32_t cycle_count = 0;
    static uint16_t last_address = 0xFFFF;
    uint16_t address = 0;
    uint8_t data = 0;
    char msg[120];

    cycle_count++;

    // Read address lines (A0-A15)
    // A0 on PC9
    if(HAL_GPIO_ReadPin(A0_GPIO_Port, A0_Pin)) address |= (1 << 0);
    // A1 on PB8
    if(HAL_GPIO_ReadPin(A1_GPIO_Port, A1_Pin)) address |= (1 << 1);
    // A2 on PB9
    if(HAL_GPIO_ReadPin(A2_GPIO_Port, A2_Pin)) address |= (1 << 2);
    // A3 on PA5
    if(HAL_GPIO_ReadPin(A3_GPIO_Port, A3_Pin)) address |= (1 << 3);
    // A4 on PA6
    if(HAL_GPIO_ReadPin(A4_GPIO_Port, A4_Pin)) address |= (1 << 4);
    // A5 on PA7
    if(HAL_GPIO_ReadPin(A5_GPIO_Port, A5_Pin)) address |= (1 << 5);
    // A6 on PB6
    if(HAL_GPIO_ReadPin(A6_GPIO_Port, A6_Pin)) address |= (1 << 6);
    // A7 on PC7
    if(HAL_GPIO_ReadPin(A7_GPIO_Port, A7_Pin)) address |= (1 << 7);
    // A8 on PA9
    if(HAL_GPIO_ReadPin(A8_GPIO_Port, A8_Pin)) address |= (1 << 8);
    // A9 on PA8
    if(HAL_GPIO_ReadPin(A9_GPIO_Port, A9_Pin)) address |= (1 << 9);
    // A10 on PB10
    if(HAL_GPIO_ReadPin(A10_GPIO_Port, A10_Pin)) address |= (1 << 10);
    // A11 on PB4
    if(HAL_GPIO_ReadPin(A11_GPIO_Port, A11_Pin)) address |= (1 << 11);
    // A12 on PB5
    if(HAL_GPIO_ReadPin(A12_GPIO_Port, A12_Pin)) address |= (1 << 12);
    // A13 on PB3
    if(HAL_GPIO_ReadPin(A13_GPIO_Port, A13_Pin)) address |= (1 << 13);
    // A14 on PA10
    if(HAL_GPIO_ReadPin(A14_GPIO_Port, A14_Pin)) address |= (1 << 14);
    // A15 on PC4
    if(HAL_GPIO_ReadPin(A15_GPIO_Port, A15_Pin)) address |= (1 << 15);

    // Read data lines (D0-D7)
    // D0 on PC2
    if(HAL_GPIO_ReadPin(D0_GPIO_Port, D0_Pin)) data |= (1 << 0);
    // D1 on PC3
    if(HAL_GPIO_ReadPin(D1_GPIO_Port, D1_Pin)) data |= (1 << 1);
    // D2 on PC0
    if(HAL_GPIO_ReadPin(D2_GPIO_Port, D2_Pin)) data |= (1 << 2);
    // D3 on PC1
    if(HAL_GPIO_ReadPin(D3_GPIO_Port, D3_Pin)) data |= (1 << 3);
    // D4 on PB0
    if(HAL_GPIO_ReadPin(D4_GPIO_Port, D4_Pin)) data |= (1 << 4);
    // D5 on PA4
    if(HAL_GPIO_ReadPin(D5_GPIO_Port, D5_Pin)) data |= (1 << 5);
    // D6 on PA1
    if(HAL_GPIO_ReadPin(D6_GPIO_Port, D6_Pin)) data |= (1 << 6);
    // D7 on PA0
    if(HAL_GPIO_ReadPin(D7_GPIO_Port, D7_Pin)) data |= (1 << 7);

    // Read R/W pin (PB7)
    uint8_t rw = HAL_GPIO_ReadPin(R_W_GPIO_Port, R_W_Pin);

    // Check if addresses are sequential (for instruction fetches)
    int16_t addr_diff = (int16_t)address - (int16_t)last_address;

    // Format output with cycle counter
    if(addr_diff != 1 && addr_diff != 2 && addr_diff != 3 && last_address != 0xFFFF) {
      // Non-sequential access - might indicate missed cycles or jump
      sprintf(msg, "[%lu] %s 0x%04X  Data: 0x%02X (jump from 0x%04X)%s\r\n",
              cycle_count,
              rw ? "READ " : "WRITE",
              address,
              data,
              last_address,
              (address == 0xFFFF && data == 0x00) ? " <-- BUS FLOAT?" : "");
    } else {
      sprintf(msg, "[%lu] %s 0x%04X  Data: 0x%02X%s\r\n",
              cycle_count,
              rw ? "READ " : "WRITE",
              address,
              data,
              (address == 0xFFFF && data == 0x00) ? " <-- BUS FLOAT?" : "");
    }

    last_address = address;

    HAL_UART_Transmit(&huart2, (uint8_t*)msg, strlen(msg), 10);
  }
}
/* USER CODE END 1 */
