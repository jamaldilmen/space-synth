// Mirror of the intended Metal besselJm() — verify the port against known
// values + the CPU reference series before it goes in the shader.
#include <cstdio>
#include <cmath>

// ---- candidate Metal port (running-product recurrence, float32) ----
float besselJm(int n, float x) {
    if (fabs(x) < 1e-6f) return (n == 0) ? 1.0f : 0.0f;
    float hx = x * 0.5f;
    float term = 1.0f;
    for (int i = 1; i <= n; i++) term *= hx / float(i); // hx^n / n!
    float sum = term;
    float hx2 = hx * hx;
    for (int k = 1; k < 30; k++) {
        term *= -hx2 / (float(k) * float(k + n));
        sum += term;
        if (fabs(term) < 1e-12f) break;
    }
    return sum;
}

// ---- CPU reference (copy of src/core/bessel.cpp, double) ----
double besselJ_ref(int n, double x) {
    if (std::abs(x) < 1e-10) return n == 0 ? 1.0 : 0.0;
    double sum = 0.0, hx = x / 2.0;
    for (int k = 0; k < 25; k++) {
        double sign = (k % 2 == 0) ? 1.0 : -1.0;
        double num = std::pow(hx, 2 * k + n);
        double den = 1.0;
        for (int i = 1; i <= k; i++) den *= i;
        for (int i = 1; i <= k + n; i++) den *= i;
        sum += sign * num / den;
    }
    return sum;
}

int main() {
    struct { int m; float x; double known; } cases[] = {
        {0, 0.0f, 1.0},        {0, 1.0f, 0.7651976866},
        {1, 1.0f, 0.4400505857}, {2, 2.0f, 0.3528340286},
        {0, 2.4048f, 0.0},     // J0 first zero
        {1, 3.8317f, 0.0},     // J1 first zero
        {3, 5.0f, 0.3648312306}, {0, 5.5201f, 0.0}, // J0 2nd zero
        {2, 8.4172f, 0.0},     // J2 2nd zero
        {0, 13.0f, 0.2069261}, {4, 10.0f, -0.2196}, // larger x stress
    };
    printf("%3s %8s | %12s %12s %12s | %s\n","m","x","port","ref","known","dPort");
    for (auto&c: cases) {
        float p = besselJm(c.m, c.x);
        double r = besselJ_ref(c.m, c.x);
        printf("%3d %8.4f | %12.6f %12.6f %12.6f | %.2e\n",
               c.m, c.x, p, r, c.known, fabs(p - c.known));
    }
    return 0;
}
