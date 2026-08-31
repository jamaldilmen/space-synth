// frustum_validate.cpp — independent validation of OFF-AXIS (asymmetric) frustum
// projection for the Cologne three-wall room. 2026-08-31.
//
// WHY THIS EXISTS BEFORE ANY RENDER CODE: a wrong projection matrix does not
// look broken. It looks plausible and is wrong at the corners, which is exactly
// where a three-wall room is judged. So the matrix is proven numerically FIRST,
// against invariants that cannot be satisfied by a near-miss.
//
// PROJECT CONVENTION (read from source, not assumed):
//   src/render/renderer.mm:4904  perspectiveMatrix()
//     m[0]=w  m[5]=h  m[10]=f/(f-n)  m[11]=1  m[14]=-n*f/(f-n)
//   => COLUMN-MAJOR (index = col*4 + row), COLUMN-VECTOR (clip = M * v),
//      LEFT-HANDED with +Z FORWARD (w_clip = +z, since M[3][2] = m[11] = 1),
//      and Metal-style depth mapping to [0,1] (z=n -> 0, z=f -> 1).
//   Every matrix below is built in THAT convention. A right-handed / OpenGL
//   [-1,1] formula copied from a CAVE paper would pass a symmetric test and
//   fail at the seam, which is why test 1 and test 5 both exist.
//
// ROOM (measured, not estimated — he walked it 2026-08-24, Polycam scan
// 256,532 verts confirmed; docs/DESIGN_2026-08-23_THREE_WALL_ROOM.md):
//   sides 14.75 x 3.50 m (x2), front 10.01 x 3.50 m, ~270 deg, three surfaces.
//   Back wall gets no beamer.
//
// Build (no part of the app build):
//   clang++ -std=c++17 -O2 -o /tmp/frustum_validate tools/frustum_validate.cpp

#include <cstdio>
#include <cmath>
#include <cstring>
#include <initializer_list>

struct V3 { double x, y, z; };
static V3 sub(V3 a, V3 b) { return {a.x-b.x, a.y-b.y, a.z-b.z}; }
static double dot(V3 a, V3 b) { return a.x*b.x + a.y*b.y + a.z*b.z; }
static V3 cross(V3 a, V3 b) {
  return {a.y*b.z - a.z*b.y, a.z*b.x - a.x*b.z, a.x*b.y - a.y*b.x};
}
static V3 norm(V3 a) { double L = sqrt(dot(a,a)); return {a.x/L, a.y/L, a.z/L}; }

// ── The SHIPPED matrix, copied verbatim from renderer.mm:4904 ───────────────
static void perspectiveMatrix(double *m, double fovY, double aspect,
                              double n, double f) {
  memset(m, 0, 16 * sizeof(double));
  double h = 1.0 / tan(fovY * 0.5);
  double w = h / aspect;
  m[0] = w; m[5] = h;
  m[10] = f / (f - n);
  m[11] = 1.0;
  m[14] = -n * f / (f - n);
}

// ── THE NEW ONE: asymmetric frustum, same convention ────────────────────────
// Derivation (not copied): a view-space point (x,y,z), z>0 forward, lands on
// the near plane at x_n = x*n/z. The near window is [l,r], so
//   ndc_x = 2*(x_n - l)/(r - l) - 1 = (2*n*x/z - (r+l)) / (r - l)
// and with w_clip = z,
//   x_clip = (2n/(r-l)) * x  -  ((r+l)/(r-l)) * z
// giving M[0][0] = 2n/(r-l) and M[0][2] = -(r+l)/(r-l).
// Column-major: M[0][2] is index 2*4+0 = 8, M[1][2] is index 2*4+1 = 9.
static void offAxisMatrix(double *m, double l, double r, double b, double t,
                          double n, double f) {
  memset(m, 0, 16 * sizeof(double));
  m[0]  = 2.0 * n / (r - l);
  m[5]  = 2.0 * n / (t - b);
  m[8]  = -(r + l) / (r - l);
  m[9]  = -(t + b) / (t - b);
  m[10] = f / (f - n);
  m[11] = 1.0;
  m[14] = -n * f / (f - n);
}

// ── Wall -> (view matrix, projection) from eye + wall rectangle ─────────────
// pa = lower-left, pb = lower-right, pc = upper-left, AS SEEN FROM INSIDE.
struct WallCam { double view[16]; double proj[16]; double l,r,b,t,d; };

static WallCam wallCamera(V3 pa, V3 pb, V3 pc, V3 pe, double n, double f) {
  WallCam W;
  V3 vr = norm(sub(pb, pa));            // wall right
  V3 vu = norm(sub(pc, pa));            // wall up
  V3 vn = norm(cross(vr, vu));          // wall normal
  V3 va = sub(pa, pe);
  // Normal must point from the wall TOWARD the eye; flip if the winding gave
  // us the outward face. (Caught by test 5 if wrong, but fix it honestly here.)
  if (dot(va, vn) > 0.0) { vn.x = -vn.x; vn.y = -vn.y; vn.z = -vn.z; }
  double d = -dot(va, vn);              // eye distance to the wall plane, > 0
  W.d = d;

  V3 vb = sub(pb, pe), vc = sub(pc, pe);
  W.l = dot(va, vr) * n / d;
  W.r = dot(vb, vr) * n / d;
  W.b = dot(va, vu) * n / d;
  W.t = dot(vc, vu) * n / d;
  offAxisMatrix(W.proj, W.l, W.r, W.b, W.t, n, f);

  // View: LH basis (right, up, forward), forward = -vn (eye -> wall).
  V3 fwd = {-vn.x, -vn.y, -vn.z};
  memset(W.view, 0, 16 * sizeof(double));
  W.view[0]=vr.x; W.view[4]=vr.y; W.view[8]=vr.z;   // row 0 = right
  W.view[1]=vu.x; W.view[5]=vu.y; W.view[9]=vu.z;   // row 1 = up
  W.view[2]=fwd.x;W.view[6]=fwd.y;W.view[10]=fwd.z; // row 2 = forward
  W.view[12] = -dot(vr, pe);
  W.view[13] = -dot(vu, pe);
  W.view[14] = -dot(fwd, pe);
  W.view[15] = 1.0;
  return W;
}

static void mul(double *o, const double *A, const double *B) { // o = A * B
  for (int c = 0; c < 4; c++)
    for (int r = 0; r < 4; r++) {
      double s = 0;
      for (int k = 0; k < 4; k++) s += A[k*4 + r] * B[c*4 + k];
      o[c*4 + r] = s;
    }
}
struct NDC { double x, y, z, w; bool behind; };
static NDC project(const double *M, V3 p) {
  double v[4] = {p.x, p.y, p.z, 1.0}, o[4] = {0,0,0,0};
  for (int r = 0; r < 4; r++)
    for (int k = 0; k < 4; k++) o[r] += M[k*4 + r] * v[k];
  NDC q; q.w = o[3]; q.behind = (o[3] <= 1e-12);
  q.x = o[0]/o[3]; q.y = o[1]/o[3]; q.z = o[2]/o[3];
  return q;
}

static int failures = 0;
static void check(const char *name, double got, double want, double tol) {
  bool ok = fabs(got - want) <= tol;
  if (!ok) failures++;
  printf("  [%s] %-46s got %+.9f  want %+.9f  (tol %.1e)\n",
         ok ? "PASS" : "FAIL", name, got, want, tol);
}

int main() {
  const double n = 0.001, f = 5000.0;   // the shipped near/far, main.cpp:937-939

  printf("=== TEST 1 — off-axis MUST reduce to the shipped perspectiveMatrix\n");
  printf("    (a symmetric window is the same camera; if this fails the\n");
  printf("     convention is wrong and nothing below means anything)\n");
  {
    double fovY = 45.0 * M_PI / 180.0, aspect = 19644.0 / 1680.0;
    double t = n * tan(fovY * 0.5), b = -t, r = t * aspect, l = -r;
    double A[16], B[16];
    perspectiveMatrix(A, fovY, aspect, n, f);
    offAxisMatrix(B, l, r, b, t, n, f);
    double worst = 0; int wi = -1;
    for (int i = 0; i < 16; i++)
      if (fabs(A[i]-B[i]) > worst) { worst = fabs(A[i]-B[i]); wi = i; }
    printf("    worst element delta = %.3e at index %d\n", worst, wi);
    check("symmetric-reduces-to-shipped", worst, 0.0, 1e-12);
  }

  printf("\n=== TEST 2/3/4 — an OFF-CENTRE window: centre->0, corners->+-1, depth\n");
  {
    double l = 1.0, r = 3.0, b = -0.5, t = 1.5;   // deliberately asymmetric
    double M[16]; offAxisMatrix(M, l, r, b, t, n, f);
    // Points ON the near plane (z = n) at the window centre and corners.
    double cx = 0.5*(l+r), cy = 0.5*(b+t);
    NDC c  = project(M, {cx, cy, n});
    NDC ll = project(M, {l, b, n});
    NDC ur = project(M, {r, t, n});
    check("window-centre -> ndc.x 0", c.x, 0.0, 1e-9);
    check("window-centre -> ndc.y 0", c.y, 0.0, 1e-9);
    check("lower-left  -> ndc.x -1", ll.x, -1.0, 1e-9);
    check("lower-left  -> ndc.y -1", ll.y, -1.0, 1e-9);
    check("upper-right -> ndc.x +1", ur.x, +1.0, 1e-9);
    check("upper-right -> ndc.y +1", ur.y, +1.0, 1e-9);
    check("depth at near -> 0", project(M, {cx, cy, n}).z, 0.0, 1e-9);
    check("depth at far  -> 1", project(M, {cx*f/n, cy*f/n, f}).z, 1.0, 1e-9);
  }

  printf("\n=== TEST 5 — THE SEAM. Cologne, measured. Two frustums, one corner.\n");
  {
    // Room: origin at floor centre. x = width (front wall 10.01),
    // z = depth (side walls 14.75), y = height (3.50). Audience inside.
    const double W = 10.01, D = 14.75, H = 3.50;
    const double hx = W*0.5, hz = D*0.5;
    V3 pe = {0.0, 1.60, 0.0};             // eye: room centre, standing height

    // FRONT wall at z = +hz, seen from inside: right is +x.
    V3 f_pa = {-hx, 0.0, +hz}, f_pb = {+hx, 0.0, +hz}, f_pc = {-hx, H, +hz};
    // LEFT wall at x = -hx, seen from inside: right is +z (toward the front).
    V3 l_pa = {-hx, 0.0, -hz}, l_pb = {-hx, 0.0, +hz}, l_pc = {-hx, H, -hz};
    // RIGHT wall at x = +hx, seen from inside: right is -z (front on the left).
    V3 r_pa = {+hx, 0.0, +hz}, r_pb = {+hx, 0.0, -hz}, r_pc = {+hx, H, +hz};

    WallCam F = wallCamera(f_pa, f_pb, f_pc, pe, n, f);
    WallCam L = wallCamera(l_pa, l_pb, l_pc, pe, n, f);
    WallCam R = wallCamera(r_pa, r_pb, r_pc, pe, n, f);
    printf("    eye->wall distances: front %.3f m, left %.3f m, right %.3f m\n",
           F.d, L.d, R.d);
    printf("    front window l/r = %+.6f %+.6f  (asymmetric in y only if centred)\n", F.l, F.r);

    double FVP[16], LVP[16], RVP[16];
    mul(FVP, F.proj, F.view); mul(LVP, L.proj, L.view); mul(RVP, R.proj, R.view);

    // The shared vertical edge FRONT^LEFT is the world line x=-hx, z=+hz.
    // On the FRONT wall it is the LEFT edge  -> ndc.x must be -1.
    // On the LEFT  wall it is the RIGHT edge -> ndc.x must be +1.
    // Vertical position must AGREE, or the corner tears.
    for (double y : {0.0, 1.60, H}) {
      V3 edge = {-hx, y, +hz};
      NDC a = project(FVP, edge), b = project(LVP, edge);
      char nm[96];
      snprintf(nm, sizeof nm, "front-left edge y=%.2f  front ndc.x", y);
      check(nm, a.x, -1.0, 1e-9);
      snprintf(nm, sizeof nm, "front-left edge y=%.2f  left  ndc.x", y);
      check(nm, b.x, +1.0, 1e-9);
      snprintf(nm, sizeof nm, "front-left edge y=%.2f  ndc.y AGREE (seam)", y);
      check(nm, a.y - b.y, 0.0, 1e-9);
    }
    // And the FRONT^RIGHT edge: x=+hx, z=+hz.
    for (double y : {0.0, H}) {
      V3 edge = {+hx, y, +hz};
      NDC a = project(FVP, edge), b = project(RVP, edge);
      char nm[96];
      snprintf(nm, sizeof nm, "front-right edge y=%.2f front ndc.x", y);
      check(nm, a.x, +1.0, 1e-9);
      snprintf(nm, sizeof nm, "front-right edge y=%.2f right ndc.x", y);
      check(nm, b.x, -1.0, 1e-9);
      snprintf(nm, sizeof nm, "front-right edge y=%.2f ndc.y AGREE (seam)", y);
      check(nm, a.y - b.y, 0.0, 1e-9);
    }
  }

  printf("\n=== TEST 6 — why slicing ONE wide image cannot work (arithmetic)\n");
  {
    // Horizontal coverage, computed HONESTLY as a sum of bearing spans from the
    // eye, not estimated. theta measured from +z, positive toward +x.
    const double W = 10.01, D = 14.75; const double hx = W*0.5, hz = D*0.5;
    const double R2D = 180.0 / M_PI;
    double aFR = atan2( hx,  hz) * R2D;        // front-right corner bearing
    double aBR = atan2( hx, -hz) * R2D;        // back-right
    double front = 2.0 * aFR;                  // front wall span
    double side  = aBR - aFR;                  // one side wall span
    double back  = 360.0 - front - 2.0 * side; // the wall with no beamer
    double three = front + 2.0 * side;
    printf("    eye at ROOM CENTRE (0, 1.60, 0), measured room %.2f x %.2f m\n", W, D);
    printf("      front wall spans %6.2f deg\n", front);
    printf("      each side wall   %6.2f deg  (x2)\n", side);
    printf("      back wall (NO beamer) %6.2f deg\n", back);
    printf("      => THE THREE PROJECTED WALLS COVER %.2f deg\n", three);
    check("three walls + back == 360", three + back, 360.0, 1e-9);
    printf("    NOTE: the board and memory both say \"~270 deg\". At the measured\n");
    printf("    geometry with the eye centred it is %.1f deg. 270 was an estimate.\n", three);
    printf("    A single flat perspective needs image width proportional to\n");
    printf("    tan(fov/2):  120deg -> %.2f   170deg -> %.2f   180deg -> INFINITE\n",
           tan(120.0*M_PI/360.0), tan(170.0*M_PI/360.0));
    printf("    %.1f deg is PAST 180. One camera cannot cover it at ANY width.\n", three);
  }

  printf("\n%s  (%d failure%s)\n", failures ? "*** FAILED ***" : "ALL PASS",
         failures, failures == 1 ? "" : "s");
  return failures ? 1 : 0;
}
