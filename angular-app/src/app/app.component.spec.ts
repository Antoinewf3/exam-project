import { TestBed } from '@angular/core/testing';
import { AppComponent } from './app.component';

describe('AppComponent', () => {
  beforeEach(async () => {
    await TestBed.configureTestingModule({
      declarations: [AppComponent],
    }).compileComponents();
  });

  it('should create the app', () => {
    const fixture = TestBed.createComponent(AppComponent);
    expect(fixture.componentInstance).toBeTruthy();
  });

  it('should have title Hello World Angular', () => {
    const fixture = TestBed.createComponent(AppComponent);
    expect(fixture.componentInstance.title).toBe('Hello World Angular');
  });

  it('should render title in h1', () => {
    const fixture = TestBed.createComponent(AppComponent);
    fixture.detectChanges();
    const compiled = fixture.nativeElement as HTMLElement;
    expect(compiled.querySelector('h1')?.textContent).toContain('Hello World Angular');
  });

  it('should display version 1.0.0', () => {
    const fixture = TestBed.createComponent(AppComponent);
    fixture.detectChanges();
    const compiled = fixture.nativeElement as HTMLElement;
    expect(compiled.textContent).toContain('1.0.0');
  });

  it('should display EKS environment', () => {
    const fixture = TestBed.createComponent(AppComponent);
    expect(fixture.componentInstance.environment).toContain('EKS');
  });

  it('should have RUNNING status', () => {
    const fixture = TestBed.createComponent(AppComponent);
    expect(fixture.componentInstance.status).toBe('RUNNING');
  });
});