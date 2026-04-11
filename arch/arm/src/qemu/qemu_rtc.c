/****************************************************************************
 * arch/arm/src/qemu/qemu_rtc.c
 *
 * SPDX-License-Identifier: Apache-2.0
 *
 * Licensed to the Apache Software Foundation (ASF) under one or more
 * contributor license agreements.  See the NOTICE file distributed with
 * this work for additional information regarding copyright ownership.  The
 * ASF licenses this file to you under the Apache License, Version 2.0 (the
 * "License"); you may not use this file except in compliance with the
 * License.  You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
 * WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.  See the
 * License for the specific language governing permissions and limitations
 * under the License.
 *
 ****************************************************************************/

/****************************************************************************
 * Included Files
 ****************************************************************************/

#include <nuttx/config.h>

#include <errno.h>
#include <stdbool.h>
#include <time.h>

#include <nuttx/arch.h>
#include <nuttx/fdt.h>
#include <nuttx/timers/arch_rtc.h>
#include <nuttx/timers/pl031.h>
#include <nuttx/timers/rtc.h>

#ifdef CONFIG_LIBC_FDT
#  include <libfdt.h>
#endif

#include "chip.h"

/****************************************************************************
 * Public Data
 ****************************************************************************/

volatile bool g_rtc_enabled = false;

/****************************************************************************
 * Private Data
 ****************************************************************************/

static uintptr_t g_qemu_rtc_base;

/****************************************************************************
 * Private Functions
 ****************************************************************************/

static int qemu_rtc_probe(uintptr_t *base, int *irq)
{
#ifdef CONFIG_LIBC_FDT
  FAR const void *fdt = fdt_get();
  int offset;

  if (fdt == NULL)
    {
      return -ENODEV;
    }

  offset = fdt_node_offset_by_compatible(fdt, -1, "arm,pl031");
  if (offset < 0)
    {
      return -ENODEV;
    }

  *base = fdt_get_reg_base(fdt, offset, 0);
  *irq = fdt_get_irq(fdt, offset, 0, QEMU_SPI_IRQ_BASE);
  if (*base == 0 || *irq < 0)
    {
      return -ENODEV;
    }

  return OK;
#else
  return -ENODEV;
#endif
}

/****************************************************************************
 * Public Functions
 ****************************************************************************/

int up_rtc_initialize(void)
{
  FAR struct rtc_lowerhalf_s *rtc_lowerhalf;
  uintptr_t base;
  int irq;
  int ret;

  ret = qemu_rtc_probe(&base, &irq);
  if (ret < 0)
    {
      return -ENODEV;
    }

  g_qemu_rtc_base = base;
  rtc_lowerhalf = pl031_initialize(base, irq);
  if (rtc_lowerhalf == NULL)
    {
      return -ENODEV;
    }

  g_rtc_enabled = true;
  up_rtc_set_lowerhalf(rtc_lowerhalf, true);
  return rtc_initialize(0, rtc_lowerhalf);
}

time_t up_rtc_time(void)
{
  volatile FAR uint32_t *rtcdr;

  if (g_qemu_rtc_base == 0)
    {
      return 0;
    }

  rtcdr = (volatile FAR uint32_t *)(g_qemu_rtc_base + 0x00);
  return *rtcdr;
}

int up_rtc_settime(FAR const struct timespec *tp)
{
  volatile FAR uint32_t *rtclr;

  if (g_qemu_rtc_base == 0 || tp == NULL)
    {
      return -ENODEV;
    }

  rtclr = (volatile FAR uint32_t *)(g_qemu_rtc_base + 0x08);
  *rtclr = (uint32_t)tp->tv_sec;

  g_rtc_enabled = true;
  return OK;
}
