/* USER CODE BEGIN Header */
/**
 ******************************************************************************
 * File Name          : freertos.c
 * Description        : Code for freertos applications
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
#include "FreeRTOS.h"
#include "task.h"
#include "main.h"
#include "cmsis_os.h"

/* Private includes ----------------------------------------------------------*/
/* USER CODE BEGIN Includes */
#include "stm32l432xx.h"
#include "spi.h"
#include "tim.h"
#include "motor_control.h"
/* USER CODE END Includes */

/* Private typedef -----------------------------------------------------------*/
/* USER CODE BEGIN PTD */

/* USER CODE END PTD */

/* Private define ------------------------------------------------------------*/
/* USER CODE BEGIN PD */

/* USER CODE END PD */

/* Private macro -------------------------------------------------------------*/
/* USER CODE BEGIN PM */

/* USER CODE END PM */

/* Private variables ---------------------------------------------------------*/
/* USER CODE BEGIN Variables */

uint8_t RX_Buffer[4];
/* USER CODE END Variables */
/* Definitions for defaultTask */
osThreadId_t defaultTaskHandle;
const osThreadAttr_t defaultTask_attributes = {
  .name = "defaultTask",
  .stack_size = 128 * 4,
  .priority = (osPriority_t) osPriorityNormal,
};

/* Private function prototypes -----------------------------------------------*/
/* USER CODE BEGIN FunctionPrototypes */

/* USER CODE END FunctionPrototypes */

void StartDefaultTask(void *argument);

void MX_FREERTOS_Init(void); /* (MISRA C 2004 rule 8.1) */

/**
  * @brief  FreeRTOS initialization
  * @param  None
  * @retval None
  */
void MX_FREERTOS_Init(void) {
  /* USER CODE BEGIN Init */

  /* USER CODE END Init */

  /* USER CODE BEGIN RTOS_MUTEX */
  /* add mutexes, ... */
  /* USER CODE END RTOS_MUTEX */

  /* USER CODE BEGIN RTOS_SEMAPHORES */
  /* add semaphores, ... */
  /* USER CODE END RTOS_SEMAPHORES */

  /* USER CODE BEGIN RTOS_TIMERS */
  /* start timers, add new ones, ... */
  /* USER CODE END RTOS_TIMERS */

  /* USER CODE BEGIN RTOS_QUEUES */
  /* add queues, ... */
  /* USER CODE END RTOS_QUEUES */

  /* Create the thread(s) */
  /* creation of defaultTask */
  defaultTaskHandle = osThreadNew(StartDefaultTask, NULL, &defaultTask_attributes);

  /* USER CODE BEGIN RTOS_THREADS */
  /* add threads, ... */
  /* USER CODE END RTOS_THREADS */

  /* USER CODE BEGIN RTOS_EVENTS */
  /* add events, ... */
  /* USER CODE END RTOS_EVENTS */

}

/* USER CODE BEGIN Header_StartDefaultTask */
/**
 * @brief  Function implementing the defaultTask thread.
 * @param  argument: Not used
 * @retval None
 */
/* USER CODE END Header_StartDefaultTask */
void StartDefaultTask(void *argument)
{
  /* USER CODE BEGIN StartDefaultTask */
  /* Infinite loop */
  (void) argument;
  uint16_t CH1_DC = 0;
  HAL_TIM_PWM_Start(&htim1, TIM_CHANNEL_1);
  HAL_TIM_PWM_Start(&htim1, TIM_CHANNEL_2);
  for (;;)
  {
    /*
    HAL_Delay(250);
    while(CH1_DC < 4095)
    {
        TIM1->CCR1 = CH1_DC;
        TIM1->CCR2 = CH1_DC;
        CH1_DC += 20;
        HAL_Delay(1);
    }
    while(CH1_DC > 0)
    {
        TIM1->CCR1 = CH1_DC;
        TIM1->CCR2 = CH1_DC;
        CH1_DC -= 20;
        HAL_Delay(1);
    }
    */
  }
  /* USER CODE END StartDefaultTask */
}

/* Private application code --------------------------------------------------*/
/* USER CODE BEGIN Application */
void HAL_GPIO_EXTI_Callback(uint16_t GPIO_Pin)
{
  // Stub implementation
  if (GPIO_Pin == CS_EXTI_Pin)
  {
    // Clear RX buffer
    for (int i = 0; i < 5; i++)
    {
      RX_Buffer[i] = 0;
    }
    // Handle CS falling edge: arm DMA, set flag, etc.
    HAL_SPI_Receive_DMA(&hspi1, RX_Buffer, 4); // Receiving in DMA mode
  }
}
void HAL_SPI_RxCpltCallback(SPI_HandleTypeDef *hspi)
{
  uint16_t left_pwm = RX_Buffer[0] | (RX_Buffer[1] << 8);
  uint16_t right_pwm = RX_Buffer[2] | (RX_Buffer[3] << 8);
  HAL_TIM_PWM_Start(&htim1, TIM_CHANNEL_1);
  HAL_TIM_PWM_Start(&htim1, TIM_CHANNEL_2);
  HAL_GPIO_WritePin(GPIOB, GPIO_PIN_3, 0);

  (void)left_pwm;
  (void)right_pwm;
  if (hspi->Instance == SPI1)
  {
    // Indicate completion (e.g., toggle LED, set flag, etc.)
    if ((left_pwm > 2400|| left_pwm < 2000)){
      TIM1->CCR1 = left_pwm;
      TIM1->CCR2 = left_pwm;
    } else {
      TIM1->CCR1 = 0;
      TIM1->CCR2 = 0;
    }
    HAL_GPIO_WritePin(GPIOB, GPIO_PIN_3, 1);
  }
}
/* USER CODE END Application */

