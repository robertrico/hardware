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
#include <stdio.h>
/* USER CODE END Includes */

/* Private typedef -----------------------------------------------------------*/
typedef StaticQueue_t osStaticMessageQDef_t;
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
extern uint16_t remotePWMTXBuffer[2];
extern uint16_t remotePWMRXBuffer[2];
extern SPI_HandleTypeDef hspi1;
/* USER CODE END Variables */
/* Definitions for defaultTask */
osThreadId_t defaultTaskHandle;
const osThreadAttr_t defaultTask_attributes = {
  .name = "defaultTask",
  .stack_size = 128 * 4,
  .priority = (osPriority_t) osPriorityNormal,
};
/* Definitions for processSPI */
osThreadId_t processSPIHandle;
const osThreadAttr_t processSPI_attributes = {
  .name = "processSPI",
  .stack_size = 128 * 4,
  .priority = (osPriority_t) osPriorityRealtime,
};
/* Definitions for spiQueue */
extern osMessageQueueId_t spiQueueHandle;
uint16_t spiQueueBuffer[2];
osStaticMessageQDef_t spiQueueControlBlock;
const osMessageQueueAttr_t spiQueue_attributes = {
  .name = "spiQueue",
  .cb_mem = &spiQueueControlBlock,
  .cb_size = sizeof(spiQueueControlBlock),
  .mq_mem = &spiQueueBuffer,
  .mq_size = sizeof(spiQueueBuffer)
};

/* Private function prototypes -----------------------------------------------*/
/* USER CODE BEGIN FunctionPrototypes */

/* USER CODE END FunctionPrototypes */

void StartDefaultTask(void *argument);
void processSPIHandler(void *argument);

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

  /* Create the queue(s) */
  /* creation of spiQueue */
  spiQueueHandle = osMessageQueueNew (16, 16, &spiQueue_attributes);

  /* USER CODE BEGIN RTOS_QUEUES */
  /* add queues, ... */
  /* USER CODE END RTOS_QUEUES */

  /* Create the thread(s) */
  /* creation of defaultTask */
  defaultTaskHandle = osThreadNew(StartDefaultTask, NULL, &defaultTask_attributes);

  /* creation of processSPI */
  processSPIHandle = osThreadNew(processSPIHandler, NULL, &processSPI_attributes);

  /* USER CODE BEGIN RTOS_THREADS */
  /* add threads, ... */
  /* USER CODE END RTOS_THREADS */

  /* USER CODE BEGIN RTOS_EVENTS */
  /* add events, ... */
  /* USER CODE END RTOS_EVENTS */
  HAL_SPI_TransmitReceive_DMA(&hspi1, remotePWMTXBuffer, remotePWMRXBuffer, 16);
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
  for(;;)
  {
    osDelay(1);
  }
  /* USER CODE END StartDefaultTask */
}

/* USER CODE BEGIN Header_processSPIHandler */
/**
* @brief Function implementing the processSPI thread.
* @param argument: Not used
* @retval None
*/
/* USER CODE END Header_processSPIHandler */
void processSPIHandler(void *argument)
{
  /* USER CODE BEGIN processSPIHandler */
  uint16_t rxBuffer[2];
  for (;;) {
	  // Wait until data arrives from ISR
	  if (xQueueReceive(spiQueueHandle, rxBuffer, portMAX_DELAY) == pdPASS) {
		  // Process dat

	  }
	  HAL_SPI_TransmitReceive_DMA(&hspi1, remotePWMTXBuffer, remotePWMRXBuffer, 16);
  }
  /* USER CODE END processSPIHandler */
}

/* Private application code --------------------------------------------------*/
/* USER CODE BEGIN Application */
/* USER CODE BEGIN 1 */
/* USER CODE END Application */

