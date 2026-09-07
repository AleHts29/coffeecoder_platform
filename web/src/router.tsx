import { type QueryClient } from '@tanstack/react-query'
import {
  createRootRouteWithContext,
  createRoute,
  createRouter,
  lazyRouteComponent,
  notFound,
  redirect,
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
import { CheckoutResult, type ResultSearch } from '@/pages/CheckoutResult'
import { Account } from '@/pages/Account'
import { AdminLayout } from '@/components/AdminLayout'

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

const checkoutResultRoute = createRoute({
  getParentRoute: () => rootRoute,
  path: '/checkout/resultado',
  validateSearch: (s: Record<string, unknown>): ResultSearch => ({
    orden: typeof s.orden === 'string' ? s.orden : '',
    estado: s.estado === 'aprobado' || s.estado === 'pendiente' || s.estado === 'rechazado' ? s.estado : undefined,
    simulado: s.simulado === true || s.simulado === '1' || s.simulado === 1 ? true : undefined,
  }),
  component: function CheckoutResultRoute() {
    const search = checkoutResultRoute.useSearch()
    return <CheckoutResult {...search} />
  },
})

const accountRoute = createRoute({
  getParentRoute: () => rootRoute,
  path: '/cuenta',
  component: Account,
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

// Admin: chunk propio (tus-js-client); las páginas se resuelven perezosamente.
const adminLazy = <K extends 'AdminContent' | 'CourseEditor' | 'CareerEditor' | 'AdminSales' | 'AdminStudents' | 'AdminStudent'>(name: K) =>
  lazyRouteComponent(() => import('@/pages/admin'), name)

const adminRoute = createRoute({ getParentRoute: () => rootRoute, path: '/admin', component: AdminLayout })
const adminIndexRoute = createRoute({
  getParentRoute: () => adminRoute,
  path: '/',
  beforeLoad: () => {
    throw redirect({ to: '/admin/contenido' })
  },
})
const adminContentRoute = createRoute({ getParentRoute: () => adminRoute, path: '/contenido', component: adminLazy('AdminContent') })
const AdminCourseEditor = adminLazy('CourseEditor')
const adminCourseRoute = createRoute({
  getParentRoute: () => adminRoute,
  path: '/cursos/$id',
  component: function AdminCourseRoute() {
    const { id } = adminCourseRoute.useParams()
    return <AdminCourseEditor id={id} />
  },
})
const AdminCareerEditor = adminLazy('CareerEditor')
const adminCareerRoute = createRoute({
  getParentRoute: () => adminRoute,
  path: '/carreras/$id',
  component: function AdminCareerRoute() {
    const { id } = adminCareerRoute.useParams()
    return <AdminCareerEditor id={id} />
  },
})
const adminSalesRoute = createRoute({ getParentRoute: () => adminRoute, path: '/ventas', component: adminLazy('AdminSales') })
const AdminStudentsPage = adminLazy('AdminStudents')
const adminStudentsRoute = createRoute({
  getParentRoute: () => adminRoute,
  path: '/alumnos',
  validateSearch: (s: Record<string, unknown>): { q: string } => ({ q: typeof s.q === 'string' ? s.q : '' }),
  component: function AdminStudentsRoute() {
    const { q } = adminStudentsRoute.useSearch()
    return <AdminStudentsPage q={q} />
  },
})
const AdminStudentPage = adminLazy('AdminStudent')
const adminStudentRoute = createRoute({
  getParentRoute: () => adminRoute,
  path: '/alumnos/$id',
  component: function AdminStudentRoute() {
    const { id } = adminStudentRoute.useParams()
    return <AdminStudentPage id={id} />
  },
})

const routeTree = rootRoute.addChildren([
  adminRoute.addChildren([adminIndexRoute, adminContentRoute, adminCourseRoute, adminCareerRoute, adminSalesRoute, adminStudentsRoute, adminStudentRoute]),
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
  checkoutResultRoute,
  accountRoute,
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
