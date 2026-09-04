// Íconos de Tabler (stroke 2, 24px) inlineados: sin dependencia extra.
import type { SVGProps } from 'react'

type Props = SVGProps<SVGSVGElement> & { size?: number }

function Icon({ size = 20, children, ...rest }: Props) {
  return (
    <svg
      xmlns="http://www.w3.org/2000/svg"
      width={size}
      height={size}
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth={2}
      strokeLinecap="round"
      strokeLinejoin="round"
      aria-hidden="true"
      focusable="false"
      {...rest}
    >
      {children}
    </svg>
  )
}

export const CoffeeIcon = (p: Props) => (
  <Icon {...p}>
    <path d="M3 14c.83 .642 2.077 1.017 3.5 1c1.423 .017 2.67 -.358 3.5 -1c.83 -.642 2.077 -1.017 3.5 -1c1.423 -.017 2.67 .358 3.5 1" />
    <path d="M8 3a2.4 2.4 0 0 0 -1 2a2.4 2.4 0 0 0 1 2" />
    <path d="M12 3a2.4 2.4 0 0 0 -1 2a2.4 2.4 0 0 0 1 2" />
    <path d="M3 10h14v5a6 6 0 0 1 -6 6h-2a6 6 0 0 1 -6 -6v-5z" />
    <path d="M16.746 16.726a3 3 0 1 0 .252 -5.555" />
  </Icon>
)

export const InfinityIcon = (p: Props) => (
  <Icon {...p}>
    <path d="M9.828 9.172a4 4 0 1 0 0 5.656a10 10 0 0 0 2.172 -2.828a10 10 0 0 1 2.172 -2.828a4 4 0 1 1 0 5.656a10 10 0 0 1 -2.172 -2.828a10 10 0 0 0 -2.172 -2.828" />
  </Icon>
)

export const RefreshIcon = (p: Props) => (
  <Icon {...p}>
    <path d="M20 11a8.1 8.1 0 0 0 -15.5 -2m-.5 -4v4h4" />
    <path d="M4 13a8.1 8.1 0 0 0 15.5 2m.5 4v-4h-4" />
  </Icon>
)

export const CertificateIcon = (p: Props) => (
  <Icon {...p}>
    <path d="M15 15m-3 0a3 3 0 1 0 6 0a3 3 0 1 0 -6 0" />
    <path d="M13 17.5v4.5l2 -1.5l2 1.5v-4.5" />
    <path d="M10 19h-5a2 2 0 0 1 -2 -2v-10c0 -1.1 .9 -2 2 -2h14a2 2 0 0 1 2 2v10a2 2 0 0 1 -1 1.73" />
    <path d="M6 9l12 0" />
    <path d="M6 12l3 0" />
    <path d="M6 15l2 0" />
  </Icon>
)

export const CreditCardIcon = (p: Props) => (
  <Icon {...p}>
    <path d="M3 5m0 3a3 3 0 0 1 3 -3h12a3 3 0 0 1 3 3v8a3 3 0 0 1 -3 3h-12a3 3 0 0 1 -3 -3z" />
    <path d="M3 10l18 0" />
    <path d="M7 15l.01 0" />
    <path d="M11 15l2 0" />
  </Icon>
)

export const PlayIcon = (p: Props) => (
  <Icon {...p}>
    <path d="M7 4v16l13 -8z" />
  </Icon>
)

export const ChevronDownIcon = (p: Props) => (
  <Icon {...p}>
    <path d="M6 9l6 6l6 -6" />
  </Icon>
)

export const ArrowRightIcon = (p: Props) => (
  <Icon {...p}>
    <path d="M5 12l14 0" />
    <path d="M13 18l6 -6" />
    <path d="M13 6l6 6" />
  </Icon>
)
