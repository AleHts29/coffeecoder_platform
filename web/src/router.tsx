import { type QueryClient } from '@tanstack/react-query'
import {
  createRootRouteWithContext,
  createRoute,
  createRouter,
  lazyRouteComponent,
  notFound,
  useRouter,
  type ErrorComponentProps,
} from '@tanstack/react-router'
import { ApiError } from '@/lib/api'
import { careerQuery, careersQuery, courseQuery, coursesQuery } from '@/lib/queries'
import { isLevel } from '@/types/catalog'
import { Layout } from '@/components/Layout'
import { ErrorState, Loading, NotFoundState } from '@/components/PageState'
import { Landing } from '@/pages/Landing'
import { Catalog, type CatalogSearch } from '@/pages/Catalog'
import { Career } from '@/pages/Career'
import { Course } from '@/pages/Course'
import { Checkout, type CheckoutSearch } from '@/pages/Checkout'
import { Login, type LoginSearch } from '@/pages/Login'
import { Register } from '@/pages/Register'
import { AuthCallback } from '@/pages/AuthCallback'
import { Dashboard } from '@/pages/Dashboard'

// Router code-based (sin plugin de generación): las rutas tipadas viven acá.
// Los loaders precargan en el QueryClient; las páginas leen con
// useSuspenseQuery, así el estado de carga y error lo maneja el router.

type RouterContext = { queryClient: QueryClient }

function RouteError({ error }: ErrorComponentProps) {
  const router = useRouter()
  const message = error instanceof ApiError ? error.message : 'algo salió mal, reintentá'
  return <ErrorState message={message} onRetry={() => router.invalidate()} />
}

// Un 404 de la API se convierte en not-found del router.
function orNotFound<T>(p: Promise<T>): Promise<T> {
  return p.catch((err: unknown) => {
    if (err instanceof ApiError && err.status === 404) throw notFound()
    throw err
  })
}

const rootRoute = createRootRouteWithContext<RouterContext>()({
  component: Layout,
  pendingComponent: Loading,
  errorComponent: RouteError,
  notFoundComponent: () => (
    <NotFoundState
      title="Esa página no existe"
      message="Puede que el enlace esté vencido o mal escrito. El catálogo sigue donde siempre."
    />
  ),
})

const indexRoute = createRoute({
  getParentRoute: () => rootRoute,
  path: '/',
  loader: ({ context: { queryClient } }) => queryClient.ensureQueryData(careersQuery()),
  component: Landing,
})

const catalogRoute = createRoute({
  getParentRoute: () => rootRoute,
  path: '/catalogo',
  validateSearch: (s: Record<string, unknown>): CatalogSearch =>
    isLevel(s.tueste) ? { tueste: s.tueste } : {},
  loader: ({ context: { queryClient } }) =>
    Promise.all([
      queryClient.ensureQueryData(careersQuery()),
      queryClient.ensureQueryData(coursesQuery()),
    ]),
  component: function CatalogRoute() {
    const { tueste } = catalogRoute.useSearch()
    return <Catalog tueste={tueste} />
  },
})

const careerRoute = createRoute({
  getParentRoute: () => rootRoute,
  path: '/carreras/$slug',
  loader: ({ context: { queryClient }, params }) =>
    orNotFound(queryClient.ensureQueryData(careerQuery(params.slug))),
  notFoundComponent: () => (
    <NotFoundState
      title="Esa carrera no existe"
      message="O ya no está disponible. Las carreras vigentes están en el catálogo."
    />
  ),
  component: function CareerRoute() {
    const { slug } = careerRoute.useParams()
    return <Career slug={slug} />
  },
})

const courseRoute = createRoute({
  getParentRoute: () => rootRoute,
  path: '/cursos/$slug',
  loader: ({ context: { queryClient }, params }) =>
    orNotFound(queryClient.ensureQueryData(courseQuery(params.slug))),
  notFoundComponent: () => (
    <NotFoundState
      title="Ese curso no existe"
      message="O ya no está disponible. Los cursos vigentes están en el catálogo."
    />
  ),
  component: function CourseRoute() {
    const { slug } = courseRoute.useParams()
    return <Course slug={slug} />
  },
})

const checkoutRoute = createRoute({
  getParentRoute: () => rootRoute,
  path: '/checkout',
  validateSearch: (s: Record<string, unknown>): CheckoutSearch => ({
    producto: s.producto === 'carrera' ? 'carrera' : 'curso',
    slug: typeof s.slug === 'string' ? s.slug : '',
  }),
  component: function CheckoutRoute() {
    const search = checkoutRoute.useSearch()
    return <Checkout {...search} />
  },
})

const redirectSearch = (s: Record<string, unknown>): LoginSearch =>
  typeof s.redirect === 'string' && s.redirect.startsWith('/') ? { redirect: s.redirect } : {}

const loginRoute = createRoute({
  getParentRoute: () => rootRoute,
  path: '/ingresar',
  validateSearch: redirectSearch,
  component: function LoginRoute() {
    const { redirect } = loginRoute.useSearch()
    return <Login redirect={redirect} />
  },
})

const registerRoute = createRoute({
  getParentRoute: () => rootRoute,
  path: '/registro',
  validateSearch: redirectSearch,
  component: function RegisterRoute() {
    const { redirect } = registerRoute.useSearch()
    return <Register redirect={redirect} />
  },
})

const dashboardRoute = createRoute({
  getParentRoute: () => rootRoute,
  path: '/panel',
  component: Dashboard,
})

const authCallbackRoute = createRoute({
  getParentRoute: () => rootRoute,
  path: '/auth/callback',
  component: AuthCallback,
})

// El player carga hls.js: va en su propio chunk para no pesar en el catálogo.
const Player = lazyRouteComponent(() => import('@/pages/Player'), 'Player')

const playerRoute = createRoute({
  getParentRoute: () => rootRoute,
  path: '/cursos/$slug/lecciones/$lessonId',
  validateSearch: (s: Record<string, unknown>): { autoplay?: boolean } =>
    s.autoplay === true || s.autoplay === 'true' ? { autoplay: true } : {},
  loader: ({ context: { queryClient }, params }) =>
    orNotFound(queryClient.ensureQueryData(courseQuery(params.slug))),
  notFoundComponent: () => (
    <NotFoundState title="Ese curso no existe" message="O ya no está disponible. Los cursos vigentes están en el catálogo." />
  ),
  component: function PlayerRoute() {
    const { slug, lessonId } = playerRoute.useParams()
    const { autoplay } = playerRoute.useSearch()
    return <Player slug={slug} lessonId={lessonId} autoplay={autoplay} />
  },
})

const routeTree = rootRoute.addChildren([
  indexRoute,
  catalogRoute,
  careerRoute,
  courseRoute,
  playerRoute,
  checkoutRoute,
  loginRoute,
  registerRoute,
  authCallbackRoute,
  dashboardRoute,
])

export function makeRouter(queryClient: QueryClient) {
  return createRouter({
    routeTree,
    context: { queryClient },
    defaultPreload: 'intent',
    defaultPreloadStaleTime: 0,
    scrollRestoration: true,
  })
}

declare module '@tanstack/react-router' {
  interface Register {
    router: ReturnType<typeof makeRouter>
  }
}
